// A scoreboard of your own: this page draws the game's scoreboard (the scoreboard@1 contract of the web interface SDK).
//
//   events   server:info {name, address, title}, scoreboard:columns {columns} (the mode's SetScoreboardColumns),
//            roster:snapshot / roster:update {players}, roster:remove {ids}, scoreboard:show {open, mode}, scoreboard:page {delta}
//   actions  roster.mute {id, muted} (stop hearing a player's voice, on this player's game), scoreboard.close
// A row's cells are the players' state values under the columns' keys. Names and cells are other players' and the mode's text:
// they go on the page with textContent. Opened in a browser (with sdk.js next to the folder) it runs in mock mode with forty players.
(() => {
  "use strict";

  const PAGE_ROWS = 16;
  const $ = (id) => document.getElementById(id);
  const board = $("board");

  let columns = [];
  let mode = "hold";
  let first = 0;               // the first row shown of the others
  const players = new Map();   // id -> roster entry

  // a cell as its column's format reads it
  function format(value, kind) {
    const text = value === undefined || value === null ? "" : String(value);
    const n = Number(text);
    if (!kind || text.trim() === "" || !Number.isFinite(n)) return text;
    if (kind === "number") return n.toLocaleString();
    if (kind === "percent") return n + "%";
    const s = Math.max(0, Math.floor(n));   // "time": seconds
    const two = (v) => String(v).padStart(2, "0");
    return s >= 3600 ? Math.floor(s / 3600) + ":" + two(Math.floor(s / 60) % 60) + ":" + two(s % 60) : Math.floor(s / 60) + ":" + two(s % 60);
  }

  function cell(tag, text, align) {
    const el = document.createElement(tag);
    el.textContent = text;
    if (align === "center" || align === "right") el.className = align;
    return el;
  }

  function renderHead() {
    const cells = [cell("th", "#"), cell("th", "Name"), ...columns.map((c) => cell("th", c.label, c.align)), cell("th", "Ping", "right")];
    if (mode === "toggle") cells.push(cell("th", ""));
    $("head").replaceChildren(...cells);
  }

  function row(p) {
    const tr = document.createElement("tr");
    if (p.self) tr.className = "self";
    tr.append(cell("td", String(p.id)));

    const name = cell("td", p.label || p.name);
    if (p.color && !p.self) name.style.color = p.color;
    const marks = [p.talking ? "speaking" : p.muted ? "muted" : "", p.inMenu ? "in a menu" : "", p.party ? "party" : ""].filter(Boolean);
    if (marks.length > 0) {
      const span = document.createElement("span");
      span.className = "marks";
      span.textContent = marks.join(", ");
      name.append(span);
    }
    tr.append(name);

    for (const c of columns) {
      const td = cell("td", format(p.cells && p.cells[c.key], c.format), c.align);
      if (c.color) td.style.color = c.color;
      tr.append(td);
    }

    const ping = cell("td", p.ping >= 0 ? String(p.ping) : "-", "right");
    ping.classList.add(p.ping >= 0 && p.ping < 100 ? "ping-good" : "ping-bad");
    tr.append(ping);

    if (mode === "toggle") {   // the page has the mouse in toggle mode: a button to mute a player's voice
      const td = document.createElement("td");
      if (!p.self) {
        const button = document.createElement("button");
        button.type = "button";
        button.tabIndex = -1;
        button.textContent = p.muted ? "Unmute" : "Mute";
        button.addEventListener("click", () => {
          KcdMp.call("roster.mute", { id: p.id, muted: !p.muted }).catch((e) => KcdMp.log.warn("mute: " + e.message));
        });
        td.append(button);
      }
      tr.append(td);
    }
    return tr;
  }

  function render() {
    const all = [...players.values()];
    const self = all.filter((p) => p.self);
    const others = all.filter((p) => !p.self).sort((a, b) => a.id - b.id);
    first = Math.max(0, Math.min(first, Math.max(0, others.length - PAGE_ROWS)));
    $("rows").replaceChildren(...self.map(row), ...others.slice(first, first + PAGE_ROWS).map(row));
    $("count").textContent = all.length === 1 ? "1 player" : all.length + " players";
    const pages = Math.ceil(others.length / PAGE_ROWS);
    $("pages").textContent = pages > 1 ? "Page " + (Math.floor(first / PAGE_ROWS) + 1) + " of " + pages + " - Page Up / Page Down" : "";
  }

  KcdMp.onComponent("server:info", (info) => {
    $("title").textContent = info.title || info.name;
  });
  KcdMp.onComponent("scoreboard:columns", (data) => {
    columns = (data && data.columns) || [];
    renderHead();
    render();
  });
  KcdMp.onComponent("roster:snapshot", (data) => {
    players.clear();
    for (const p of (data && data.players) || []) players.set(p.id, p);
    render();
  });
  KcdMp.onComponent("roster:update", (data) => {
    for (const p of (data && data.players) || []) players.set(p.id, p);
    render();
  });
  KcdMp.onComponent("roster:remove", (data) => {
    for (const id of (data && data.ids) || []) players.delete(id);
    render();
  });
  KcdMp.onComponent("scoreboard:show", (data) => {
    mode = data.mode === "toggle" ? "toggle" : "hold";
    if (data.open && board.hidden) first = 0;   // every opening starts on the first page
    board.hidden = !data.open;
    $("close").hidden = mode !== "toggle";
    renderHead();
    render();
  });
  KcdMp.onComponent("scoreboard:page", (data) => {
    first = Math.max(0, first + data.delta * PAGE_ROWS);
    render();
  });

  const close = () => KcdMp.call("scoreboard.close").catch(() => {});
  $("close").addEventListener("click", close);
  board.addEventListener("wheel", (e) => {   // in toggle mode the page has the mouse
    e.preventDefault();
    first = Math.max(0, first + (e.deltaY > 0 ? 3 : -3));
    render();
  }, { passive: false });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !board.hidden && mode === "toggle") {
      e.preventDefault();
      close();
    }
  });

  // ---- in a browser: forty players, the board open in toggle mode
  if (KcdMp.env.mock) {
    KcdMp.mock.component("server:info", { name: "Example server", address: "127.0.0.1:7777", title: "Example scoreboard" });
    KcdMp.mock.component("scoreboard:columns", {
      columns: [
        { key: "kills", label: "Kills", align: "right", format: "number", width: 90, color: "" },
        { key: "deaths", label: "Deaths", align: "right", format: "number", width: 90, color: "" },
        { key: "played", label: "Played", align: "right", format: "time", width: 110, color: "" },
      ],
    });
    const names = ["Henry", "Hans", "Radzig", "Theresa", "Bozhena", "Kunesh", "Pius", "Godwin"];
    const roster = [];
    for (let id = 0; id < 40; id++) {
      roster.push({
        id, name: names[id % names.length] + (id >= names.length ? id : ""), label: "", color: "", team: -1, ping: 18 + (id * 7) % 140,
        inMenu: id % 9 === 4, talking: id % 7 === 2, muted: id % 11 === 6, party: id % 5 === 1, self: id === 0,
        cells: { kills: String((id * 37) % 23), deaths: String((id * 13) % 11), played: String(id * 611) },
      });
    }
    KcdMp.mock.component("roster:snapshot", { players: roster });
    KcdMp.mock.component("scoreboard:show", { open: true, mode: "toggle" });
  }
})();
