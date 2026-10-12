// A chat of your own: this page draws the game's chat (the chat@1 contract of the web interface SDK).
//
// The game hands the page the chat's events through KcdMp.onComponent and the page asks for things through KcdMp.call:
//   events   chat:config (channels, commands, limits), chat:history (the lines so far), chat:message (each new line),
//            chat:open (the player pressed Enter: the page has the keyboard and the cursor now), chat:close, chat:clear,
//            chat:scroll (Page Up / Page Down while the box is closed)
//   actions  chat.send {text, channel}, chat.close, chat.layout {x, y, w, h}
// Every text in a line is the server's or another player's: it is put on the page with textContent, never as HTML.
// Opened in a browser (with sdk.js next to the folder) the page runs in mock mode: a few lines come in and Enter opens the box.
(() => {
  "use strict";

  const MAX_LINES = 100;    // lines kept on the page
  const FADE_AFTER = 15000; // ms: a line fades while the box is closed
  const HISTORY = 20;       // lines the player sent, for the Up key

  const $ = (id) => document.getElementById(id);
  const chat = $("chat");
  const linesEl = $("lines");
  const newerEl = $("newer");
  const entry = $("entry");
  const channelsEl = $("channels");
  const input = $("input");
  const suggestionsEl = $("suggestions");

  let config = { maxChars: 256, scrollStep: 5, channels: [], suggestions: [], secretCommands: [] };
  const lines = [];   // {node, at}
  const sent = [];
  let open = false;
  let pinned = true;  // the view shows the newest line
  let channel = "";   // "" = the default channel
  let recall = -1;
  let draft = "";

  // ---- the lines

  function lineNode(line) {
    const el = document.createElement("div");
    el.className = "line";
    if (line.kind === "server") el.classList.add("server");
    if (line.channel && line.channelLabel) {
      const label = document.createElement("span");
      label.className = "channel";
      label.textContent = "[" + line.channelLabel + "]";
      if (line.channelColor) label.style.color = line.channelColor;
      el.append(label);
    }
    if (line.author) {
      const who = document.createElement("span");
      who.className = "author";
      who.textContent = line.author + ": ";
      if (line.color) who.style.color = line.color;
      el.append(who);
    }
    // a line in pieces (the mode's SendChatMessage spans), or one text in one colour
    const pieces = Array.isArray(line.spans) && line.spans.length > 0 ? line.spans : [{ text: line.text }];
    for (const piece of pieces) {
      const span = document.createElement("span");
      span.textContent = piece.text;
      const color = piece.color || (line.author ? "" : line.color);
      if (color) span.style.color = color;
      if (piece.bold) span.style.fontWeight = "700";
      if (piece.italic) span.style.fontStyle = "italic";
      el.append(span);
    }
    return el;
  }

  function add(line) {
    const node = lineNode(line);
    lines.push({ node, at: Date.now() });
    linesEl.append(node);
    while (lines.length > MAX_LINES) lines.shift().node.remove();
  }

  function clearLines() {
    lines.splice(0).forEach((l) => l.node.remove());
    pinned = true;
  }

  // positive = towards the older lines
  function scroll(rows) {
    const most = Math.max(0, linesEl.scrollHeight - linesEl.clientHeight);
    linesEl.scrollTop = Math.min(most, Math.max(0, linesEl.scrollTop - rows * 23));
    pinned = most - linesEl.scrollTop < 2;
    refresh();
  }

  function refresh() {
    chat.hidden = lines.length === 0 && !open;
    chat.classList.toggle("open", open);
    fade();
    if (pinned) linesEl.scrollTop = linesEl.scrollHeight;
    let newer = 0;
    if (!pinned) {
      const edge = linesEl.getBoundingClientRect().bottom;
      for (let i = lines.length - 1; i >= 0 && lines[i].node.getBoundingClientRect().bottom > edge + 1; i--) newer += 1;
    }
    newerEl.hidden = newer === 0;
    newerEl.textContent = newer === 1 ? "... 1 newer line" : "... " + newer + " newer lines";
    reportLayout();
  }

  // old lines fade while the box is closed, and the backing with the last of them; opening the box shows them all again (the CSS)
  function fade() {
    const now = Date.now();
    for (const l of lines) l.node.classList.toggle("faded", now - l.at > FADE_AFTER);
    chat.classList.toggle("idle", !open && lines.every((l) => now - l.at > FADE_AFTER));
  }
  setInterval(fade, 1000);

  // where the chat is, in pixels of a screen 1080 tall: the game moves its own panels that share the corner out of the way
  let reported = "";
  let reportTimer = 0;
  function reportLayout() {
    clearTimeout(reportTimer);
    reportTimer = setTimeout(() => {
      const u = window.innerHeight / 1080 || 1;
      const r = chat.hidden ? { left: 0, top: 0, width: 0, height: 0 } : chat.getBoundingClientRect();
      const box = { x: Math.round(r.left / u), y: Math.round(r.top / u), w: Math.round(r.width / u), h: Math.round(r.height / u) };
      const key = JSON.stringify(box);
      if (key !== reported) {
        reported = key;
        KcdMp.call("chat.layout", box).catch(() => {});
      }
    }, 250);
  }

  // ---- the box

  function sendableChannels() {
    return config.channels.filter((c) => c.canSend);
  }

  function renderChannels() {
    const tabs = [{ name: "", label: "All" }, ...sendableChannels()];
    if (!tabs.some((c) => c.name === channel)) channel = "";
    channelsEl.hidden = tabs.length < 2;
    channelsEl.replaceChildren(...tabs.map((c) => {
      const tab = document.createElement("button");
      tab.type = "button";
      tab.tabIndex = -1;
      tab.textContent = c.label;
      tab.setAttribute("role", "tab");
      tab.setAttribute("aria-selected", String(c.name === channel));
      tab.addEventListener("mousedown", (e) => e.preventDefault());   // keep the focus in the box
      tab.addEventListener("click", () => { channel = c.name; renderChannels(); input.focus(); });
      return tab;
    }));
  }

  function isSecret(text) {
    const m = /^\/(\S+)\s/.exec(text);
    return m !== null && config.secretCommands.includes(m[1].toLowerCase());
  }

  // the commands that start with what was typed after "/" (only while the first word is typed)
  let matches = [];
  let picked = 0;
  function renderSuggestions() {
    const text = input.value;
    matches = text.startsWith("/") && !text.includes(" ")
      ? config.suggestions.filter((s) => s.name.startsWith(text.slice(1).toLowerCase())).sort((a, b) => a.name.localeCompare(b.name)).slice(0, 6)
      : [];
    picked = Math.min(picked, Math.max(0, matches.length - 1));
    suggestionsEl.hidden = matches.length === 0;
    suggestionsEl.replaceChildren(...matches.map((s, i) => {
      const li = document.createElement("li");
      li.classList.toggle("picked", i === picked);
      const name = document.createElement("b");
      name.textContent = "/" + s.name;
      li.append(name, document.createTextNode((s.params ? " " + s.params : "") + (s.help ? " - " + s.help : "")));
      return li;
    }));
  }

  function openBox(prefill) {
    open = true;
    entry.hidden = false;
    input.maxLength = config.maxChars;
    input.value = prefill || "";
    recall = -1;
    renderChannels();
    renderSuggestions();
    refresh();
    input.focus();
  }

  function closeBox() {
    open = false;
    entry.hidden = true;
    input.value = "";
    input.removeAttribute("data-secret");
    suggestionsEl.hidden = true;
    input.blur();
    pinned = true;
    refresh();
  }

  // Enter: say the line, then close. The game takes a line only while the box is open, so chat.close waits for chat.send's answer.
  function sendLine() {
    const text = input.value;
    let said = Promise.resolve();
    if (text.trim() !== "") {
      // a command goes on the default channel; a line on the picked one
      said = KcdMp.call("chat.send", text.startsWith("/") || channel === "" ? { text } : { text, channel })
        .catch((e) => KcdMp.log.warn("the line was refused: " + e.message));
      if (!isSecret(text) && sent[sent.length - 1] !== text) {
        sent.push(text);
        if (sent.length > HISTORY) sent.shift();
      }
    }
    closeBox();
    said.then(() => KcdMp.call("chat.close")).catch(() => {});
  }

  input.addEventListener("input", () => {
    input.toggleAttribute("data-secret", isSecret(input.value));
    renderSuggestions();
  });

  input.addEventListener("keydown", (e) => {
    if (e.isComposing) return;
    switch (e.key) {
      case "Enter":
        e.preventDefault();
        if (!e.repeat) sendLine();
        break;
      case "Escape":
        e.preventDefault();   // the page closes the box itself (and the SDK's own Esc handling stays out of it)
        closeBox();
        KcdMp.call("chat.close").catch(() => {});
        break;
      case "Tab":
        e.preventDefault();
        if (matches.length > 0) {
          input.value = "/" + matches[picked].name + " ";
          renderSuggestions();
        } else if (!input.value.startsWith("/")) {
          const order = ["", ...sendableChannels().map((c) => c.name)];
          channel = order[(order.indexOf(channel) + 1) % order.length];
          renderChannels();
        }
        break;
      case "ArrowUp":
      case "ArrowDown": {
        e.preventDefault();
        const up = e.key === "ArrowUp";
        if (matches.length > 0) {   // move through the suggestions
          picked = (picked + (up ? matches.length - 1 : 1)) % matches.length;
          renderSuggestions();
          break;
        }
        if (sent.length === 0) break;   // or through the lines sent before
        if (up) {
          if (recall === -1) { draft = input.value; recall = sent.length - 1; } else if (recall > 0) recall -= 1;
        } else if (recall !== -1) {
          recall = recall + 1 >= sent.length ? -1 : recall + 1;
        }
        input.value = recall === -1 ? draft : sent[recall];
        break;
      }
      case "PageUp":
      case "PageDown":
        e.preventDefault();
        scroll(e.key === "PageUp" ? config.scrollStep : -config.scrollStep);
        break;
    }
  });

  // a click on the page's own parts must not take the focus out of the box
  input.addEventListener("blur", () => {
    if (open) setTimeout(() => open && document.hasFocus() && input.focus(), 0);
  });
  window.addEventListener("resize", refresh);

  // ---- the game's side

  KcdMp.onComponent("chat:config", (data) => {
    config = Object.assign({ maxChars: 256, scrollStep: 5, channels: [], suggestions: [], secretCommands: [] }, data);
    input.maxLength = config.maxChars;
    renderChannels();
  });
  KcdMp.onComponent("chat:history", (data) => {
    clearLines();
    for (const line of (data && data.lines) || []) add(line);
    refresh();
  });
  KcdMp.onComponent("chat:message", (line) => {
    add(line);
    refresh();
  });
  KcdMp.onComponent("chat:clear", () => {
    clearLines();
    refresh();
  });
  KcdMp.onComponent("chat:scroll", (data) => scroll(data.lines));
  KcdMp.onComponent("chat:open", (data) => openBox(data && data.prefill));
  KcdMp.onComponent("chat:close", closeBox);   // the game closed it (a menu opened, the page lost the keyboard)

  // ---- in a browser: a few lines, a channel and a command; Enter opens the box
  if (KcdMp.env.mock) {
    KcdMp.mock.component("chat:config", {
      maxChars: 256, scrollStep: 5,
      channels: [{ name: "trade", label: "Trade", color: "#e0c060", canSend: true }],
      suggestions: [{ name: "roll", help: "Roll a die for everyone to see", params: "[sides]" }, { name: "help", help: "The commands", params: "" }],
      secretCommands: ["login"],
    });
    KcdMp.mock.component("chat:history", {
      lines: [
        { kind: "server", text: "Welcome to the example server.", color: "#ffd070", spans: [] },
        { kind: "player", author: "Hans", color: "#f6e890", text: "Good morrow!", spans: [] },
        { kind: "player", author: "Henry", color: "#f6e890", text: "Anyone selling arrows?", channel: "trade", channelLabel: "Trade", channelColor: "#e0c060", spans: [] },
        { kind: "mode", spans: [{ text: "Hans", color: "#f6e890", bold: true }, { text: " rolls a d6: " }, { text: "4", bold: true }] },
      ],
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !open) KcdMp.mock.component("chat:open", { prefill: "" });
    });
  }
})();
