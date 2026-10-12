// window.KcdMp - the page side of the bridge (docs/cef-ui.md §9.6; Phase 4a). Served by the client on every origin of ours at
// /__kcdmp/sdk.js and put first in every served document's <head>. Outside the game KcdMp.env.mock is true, every call resolves
// locally and KcdMp.mock drives the handlers. Every public member has an "@api" line (the docs generator reads them).
// Phase 5a: a frame the server assigned a component to (the chat, the scoreboard) hears that component's events through
// KcdMp.onComponent; the SDK keeps their state (the config, the chat's history, the roster) and replays it to a late subscriber.
(() => {
  "use strict";
  if (window.KcdMp) {
    return;
  }
  const ROOT_ORIGIN = "https://ui.kcd-mp.invalid";
  // UI developer mode's dev URL (docs/cef-ui.md §11.6): a frame whose page a dev server on the player's own PC serves gets this script from
  // the engine with __kcdmp_dev set first - its frame's name and its bridge path, a secret of this game's run; outside the game a page
  // that loads its own copy has none, and mocks
  const dev = typeof self.__kcdmp_dev === "object" && self.__kcdmp_dev !== null && typeof self.__kcdmp_dev.frame === "string" &&
              typeof self.__kcdmp_dev.base === "string" ? self.__kcdmp_dev : null;
  const host = location.hostname;
  const isRoot = location.origin === ROOT_ORIGIN;
  // v83 (docs/cef-surfaces.md): a surface's page is a browser of its own - no root above it - on <surface>.s.<serverid>.kcd-mp-server.invalid,
  // one origin for every copy of that page (the engine tells each copy which surface it is)
  const surfaceHost = dev === null && window.parent === window ? /^([a-z][a-z0-9-]{0,31})\.s\.[^.]+\.kcd-mp-server\.invalid$/.exec(host) : null;
  const isSurface = surfaceHost !== null;
  // a server frame lives in the root's iframe
  const inGame = isRoot || isSurface || ((dev !== null || host.endsWith(".kcd-mp-server.invalid")) && window.parent !== window);
  const frame = isRoot ? "root" : !inGame || isSurface ? "" : dev !== null ? dev.frame : host.split(".")[0];
  const BRIDGE = dev !== null ? dev.base : "/__kcdmp/";
  const NAME = /^(?!\.+$)[a-z0-9_.:-]{1,64}$/;   // an event name or an action: the engine's route grammar

  // what the engine's hello says (at every ready) and the feeds' last values
  const state = { contract: "", component: "", dev: false, visibility: { visible: true, reason: "" }, playerCursor: false };
  const handlers = { message: [], error: [], visibility: [], playerCursor: [], server: new Map(), binding: new Map(), component: new Map(), use: [] };
  // v83: which surface this copy of a surface page is (the engine's hello says the rest: its entity id and its page's pixels)
  const surface = isSurface ? { name: surfaceHost[1], id: 0, width: window.innerWidth, height: window.innerHeight } : null;
  const feedSubs = new Map();     // feed name -> Set of fn
  const feedLatest = new Map();   // feed name -> the last data
  const mockReplies = new Map();  // mock mode: name -> what KcdMp.post answers

  function stringify(value) {
    if (typeof value === "string") {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (e) {
      return String(value);
    }
  }

  // page -> native: a POST to our own origin (the engine knows the caller by its frame, §9.2); 10 s at most. The result is the
  // response's JSON; a non-2xx answer rejects with its {"error"}.
  async function call(route, name, data) {
    if (!inGame) {
      if (route === "post" && mockReplies.has(name)) {
        return mockReplies.get(name)(data);
      }
      return { ok: true, mock: true };
    }
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 10000);
    try {
      const response = await fetch(`${BRIDGE}${route}/${name}`, {
        method: "POST",
        headers: { "X-KcdMp": "1", "Content-Type": "application/json" },
        body: JSON.stringify(data === undefined ? null : data),
        signal: abort.signal,
        cache: "no-store",
        credentials: "omit",
        // a same-origin POST carries "Origin: null" under a no-referrer policy (the Fetch spec), and the engine checks Origin
        referrerPolicy: "same-origin",
      });
      const text = await response.text();
      let value;
      try {
        value = JSON.parse(text);
      } catch (e) {
        value = text;
      }
      if (!response.ok) {
        throw new Error((value && value.error) || `HTTP ${response.status}`);
      }
      return value;
    } finally {
      clearTimeout(timer);
    }
  }

  function send(level, args) {
    call("sys", "log", { level, text: args.map(stringify).join(" ").slice(0, 2000) }).catch(() => {});
  }
  // a handler that throws stays its own: logged, the others still run
  function fire(list, ...args) {
    for (const fn of list ? [...list] : []) {
      try { fn(...args); } catch (x) { send("error", [`a handler threw: ${x && x.message}`]); }
    }
  }
  function fn_(f) {
    if (typeof f !== "function") {
      throw new TypeError("a handler is a function");
    }
    return f;
  }
  function name_(name) {
    if (typeof name !== "string" || !NAME.test(name)) {
      throw new Error("a name is 1 to 64 of a-z 0-9 _ . : -");
    }
    return name;
  }
  function add(list, f) {   // -> the function that takes it off again
    list.push(fn_(f));
    return () => { const at = list.indexOf(f); if (at >= 0) list.splice(at, 1); };
  }
  function addTo(map, key, f) {
    if (!map.has(key)) map.set(key, []);
    return add(map.get(key), f);
  }

  // @api function log.info
  // @api function log.warn
  // @api function log.error
  const log = Object.freeze({
    info: (...args) => send("info", args),
    warn: (...args) => send("warn", args),
    error: (...args) => send("error", args),
  });

  // The game's own typefaces (docs/cef-ui.md §11.4): the root declares them in its document; a server's frame gets the same faces here,
  // each loaded from the root's host the first time the page draws text in it ("KcdMp Regular" with its bold and italic, "KcdMp Light"
  // with its two, "KcdMp Display", "KcdMp Manuscript"). Outside the game there is no such host: the page's fallback fonts draw.
  const FACES = [
    ["KcdMp Regular", "regular", "400", "normal"], ["KcdMp Regular", "bold", "700", "normal"], ["KcdMp Regular", "italic", "400", "italic"],
    ["KcdMp Light", "light", "400", "normal"], ["KcdMp Light", "light-bold", "700", "normal"], ["KcdMp Light", "light-italic", "400", "italic"],
    ["KcdMp Display", "display", "400", "normal"], ["KcdMp Manuscript", "manuscript", "400", "normal"],
  ];
  if (inGame && !isRoot && typeof FontFace === "function" && document.fonts) {
    for (const [family, file, weight, style] of FACES) {
      try {
        document.fonts.add(new FontFace(family, `url(${ROOT_ORIGIN}/fonts/${file}.ttf) format("truetype")`, { weight, style, display: "swap" }));
      } catch (e) {
        // (a face the engine cannot make draws in the page's fallback font)
      }
    }
  }

  // The game's own picture of an item (docs/cef-ui.md §11.4): the URL of its 64 x 64 PNG for an <img> or a CSS background - `key` is the
  // item class's GUID or its game name ("longSwordDuel", any case); "" for a key of another shape. The picture comes from the player's
  // own game, made when a page asks (a fetch() of it is refused). Outside the game a plain square stands in.
  const GUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  const ITEM_NAME = /^[A-Za-z0-9_]{1,64}$/;
  const MOCK_ICON = "data:image/svg+xml," + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect x="5" y="5" width="54" height="54" rx="6" ' +
    'fill="#3b342b" stroke="#8a7a5c" stroke-width="2"/><path d="M22 42 L32 20 L42 42 Z" fill="#8a7a5c"/></svg>');
  function itemIcon(key) {
    if (typeof key !== "string" || !(GUID.test(key) || ITEM_NAME.test(key))) {
      return "";
    }
    return inGame ? `${ROOT_ORIGIN}/icons/items/${key}.png` : MOCK_ICON;
  }

  // the page's own errors: to the web log and, when the mode asked to hear them, to the server (the engine rations them)
  function relative(url) {
    try {
      const u = new URL(url, location.href);
      return u.origin === location.origin ? u.pathname.slice(1) : "";
    } catch (e) {
      return "";
    }
  }
  function reportError(message, source, line) {
    call("sys", "error", {
      message: String(message).slice(0, 1024),
      source: relative(source).slice(0, 256),
      line: Number.isInteger(line) && line > 0 ? line : 0,
    }).catch(() => {});
  }
  window.addEventListener("error", (e) => {
    reportError(e.message, e.filename, e.lineno);
    fire(handlers.error, e.error || new Error(e.message));
  });
  window.addEventListener("unhandledrejection", (e) => {
    const reason = e.reason && e.reason.message ? e.reason.message : stringify(e.reason);
    reportError(`unhandled rejection: ${reason}`, "", 0);
    fire(handlers.error, e.reason instanceof Error ? e.reason : new Error(reason));
  });

  // the focused element, through the open shadow roots of components (document.activeElement is the host of a shadow tree)
  function deepActive() {
    let el = document.activeElement;
    while (el && el.shadowRoot && el.shadowRoot.activeElement) {
      el = el.shadowRoot.activeElement;
    }
    return el;
  }

  // an editable element has the focus (the engine's editable flag, §7.2)
  const NOT_TEXT = ["button", "checkbox", "radio", "range", "submit", "reset", "color", "file", "image", "hidden"];
  function isEditable(el) {
    if (!el) {
      return false;
    }
    if (el.isContentEditable || el.tagName === "TEXTAREA" || el.tagName === "SELECT") {
      return true;
    }
    return el.tagName === "INPUT" && !NOT_TEXT.includes((el.type || "").toLowerCase());
  }
  let editable = false;
  function updateEditable() {
    const on = isEditable(deepActive());
    if (on !== editable) {
      editable = on;
      call("sys", "editable", { on }).catch(() => {});
    }
  }
  document.addEventListener("focusin", updateEditable, true);
  document.addEventListener("focusout", () => setTimeout(updateEditable, 0), true);

  // autofocus (2026-10-03): Chromium never autofocuses a field inside a frame of another origin - every server frame is one - so a page's
  // autofocus field had no focus when the frame got the keyboard, and the keys went nowhere until a click. The field takes the focus, as
  // long as nothing else in the page has it, when the frame's window does (the game hands a frame the keys by focusing it), when the
  // engine says the frame holds the keyboard (its "focus" nudge) and when a key reaches the page first - the window's focus event alone
  // needs the browser to gain the focus after the frame got it, and a player who could not type "agree" into BasicRP's welcome until an
  // alt-tab had none (the two-player round of 2026-10-07)
  function focusAutofocus() {
    const active = deepActive();
    if (active && active !== document.body && active !== document.documentElement) {
      return;
    }
    const field = document.querySelector("[autofocus]");
    if (field && typeof field.focus === "function") {
      field.focus();
    }
  }
  window.addEventListener("focus", focusAutofocus);
  // (the capture phase: the key's own character arrives as the next event, at the field that has the focus by then)
  window.addEventListener("keydown", focusAutofocus, true);

  // The component this frame draws, if the server assigned it one (chat@1, scoreboard@1 ...): the engine's `assign` says it (and the hello at
  // every ready). Its events come as {__kcdmp: {t: "component", name, data}}. The SDK keeps the state of those that are a state - the
  // config, the columns, the title, the show flag, the chat's lines (up to 200, kept up to date with chat:message and chat:clear) and the
  // roster (kept up to date with roster:update and roster:remove) - so a handler that subscribes late is told them at once.
  const HISTORY_MAX = 200;
  const STATE_EVENTS = ["server:info", "chat:config", "chat:history", "scoreboard:columns", "roster:snapshot", "scoreboard:show",
                        "hudtext:snapshot", "gametext:show", "sleep:slept", "death:show",
                        "party:config", "party:state", "party:vitals", "party:invite",
                        "voice:self", "voice:talking", "voice:muted", "voice:levels",
                        "emotes:list", "emotes:open", "emotes:pointer",
                        "shop:open", "shop:list", "shop:state", "player:purse",
                        "dialog:open", "dialog:cursor",
                        "loading:state", "loading:handover", "loading:end"];   // (from hudtext:snapshot on: Phase 5b)
  const kept = new Map();   // event name -> {data, at}: its last data and when it came (the chat's lines, the roster and the HUD texts are below)
  let history = null;       // the chat's lines, oldest first
  let roster = null;        // id -> entry
  let hudTexts = null;      // id -> element (hudtext@1)
  let shopLists = [null, null];   // the shop's Buy and Sell lists (shop@1: shop:list per tab)

  function playersOf(data) {
    return data && Array.isArray(data.players) ? data.players.filter((p) => p && Number.isInteger(p.id)) : [];
  }

  function elementsOf(data) {
    return data && Array.isArray(data.elements) ? data.elements.filter((e) => e && Number.isInteger(e.id)) : [];
  }

  // what a late subscriber to a state event is told, or undefined when nothing was said yet. A state that runs out (a GameText, a sleep's
  // fade: they carry `until`) is told only while it lasts, its remainingMs / elapsedMs moved on by the time that passed.
  function replayOf(name) {
    if (name === "chat:history") return history ? { lines: history.slice() } : undefined;
    if (name === "roster:snapshot") return roster ? { players: [...roster.values()] } : undefined;
    if (name === "hudtext:snapshot") return hudTexts ? { elements: [...hudTexts.values()] } : undefined;
    const entry = kept.get(name);
    if (!entry) return undefined;
    const data = entry.data;
    if (name === "death:show") {
      // the player is dead until death:hide, whenever the respawn was due: the time to it moved on
      if (!data || typeof data !== "object" || typeof data.until !== "number" || data.until === 0) return data;
      return Object.assign({}, data, { respawnMs: Math.max(0, data.until - Date.now()) });
    }
    if (data && typeof data === "object" && typeof data.until === "number") {
      const now = Date.now();
      if (now >= data.until) return undefined;
      const moved = Object.assign({}, data);
      if (typeof moved.remainingMs === "number") moved.remainingMs = Math.max(0, data.until - now);
      if (typeof moved.elapsedMs === "number") moved.elapsedMs = data.elapsedMs + Math.max(0, now - entry.at);
      if (typeof moved.seconds === "number") moved.seconds = Math.max(1, Math.ceil((data.until - now) / 1000));   // (an invitation's)
      return moved;
    }
    return data;
  }

  function componentEvent(name, data) {
    switch (name) {
      case "chat:history":
        history = data && Array.isArray(data.lines) ? data.lines.slice(-HISTORY_MAX) : [];
        break;
      case "chat:message":
        if (data && typeof data === "object") {
          history = history || [];
          history.push(data);
          if (history.length > HISTORY_MAX) history.splice(0, history.length - HISTORY_MAX);
        }
        break;
      case "chat:clear":
        history = [];
        break;
      case "roster:snapshot":
        roster = new Map(playersOf(data).map((p) => [p.id, p]));
        break;
      case "roster:update":
        roster = roster || new Map();
        for (const p of playersOf(data)) roster.set(p.id, p);
        break;
      case "roster:remove":
        if (roster) for (const id of data && Array.isArray(data.ids) ? data.ids : []) roster.delete(id);
        break;
      case "hudtext:snapshot":
        hudTexts = new Map(elementsOf(data).map((e) => [e.id, e]));
        break;
      case "hudtext:update":
        hudTexts = hudTexts || new Map();
        for (const e of elementsOf(data)) hudTexts.set(e.id, e);
        break;
      case "hudtext:remove":
        if (hudTexts) for (const id of data && Array.isArray(data.ids) ? data.ids : []) hudTexts.delete(id);
        break;
      case "death:hide":
        kept.delete("death:show");   // (on their feet again: a late handler is told no death)
        break;
      case "party:invite-end":
        kept.delete("party:invite");   // (answered, withdrawn or run out)
        break;
      case "emotes:close":
        kept.delete("emotes:open");   // (a late handler is told no wheel)
        kept.delete("emotes:pointer");
        break;
      case "shop:open":
        kept.set(name, { data, at: Date.now() });
        shopLists = [null, null];   // (another shop: its lists follow)
        kept.delete("shop:state");
        break;
      case "shop:list":
        if (data && typeof data === "object") shopLists[data.tab === 1 ? 1 : 0] = data;
        break;
      case "shop:close":
        kept.delete("shop:open");   // (a late handler is told no shop)
        kept.delete("shop:state");
        shopLists = [null, null];
        break;
      case "dialog:open":
        kept.set(name, { data, at: Date.now() });
        kept.delete("dialog:cursor");   // (a new page: its own highlight)
        break;
      case "dialog:close":
        kept.delete("dialog:open");   // (a late handler is told no dialog)
        kept.delete("dialog:cursor");
        break;
      default:
        if (STATE_EVENTS.includes(name)) kept.set(name, { data, at: Date.now() });
    }
    fire(handlers.component.get(name), data, name);
    fire(handlers.component.get("*"), data, name);
  }

  // The frame was assigned a component, another one or none (""): what the old one left is forgotten, the new one's snapshot follows
  function assigned(component, contract) {
    component = typeof component === "string" ? component : "";
    contract = typeof contract === "string" ? contract : "";
    if (component === state.component && contract === state.contract) {
      return;
    }
    if (component !== state.component) {
      kept.clear();
      history = null;
      roster = null;
      hudTexts = null;
      shopLists = [null, null];
    }
    state.component = component;
    state.contract = contract;
    fire(handlers.component.get("assign"), { component, contract }, "assign");
    fire(handlers.component.get("*"), { component, contract }, "assign");
  }

  // The loading screen's drawer says when it shows (loading@1's loading.shown): two animation frames after each assignment the page has
  // drawn what it was told, and the engine shows it in the native screen's place from then on. Sent by the SDK itself - a page does nothing.
  let shownPending = false;
  function loadingShownSoon() {
    if (shownPending) {
      return;
    }
    shownPending = true;
    requestAnimationFrame(() => requestAnimationFrame(() => {
      shownPending = false;
      if (state.component === "loading") {
        call("call", "loading.shown", {}).catch(() => {});
      }
    }));
  }

  // what the engine itself says, as {__kcdmp: {t, ...}} (never what a mode or a script sent: that arrives as it is, in onMessage)
  function engineMessage(m) {
    switch (m.t) {
      case "ping":
        if (Number.isInteger(m.n)) {
          call("sys", "pong", { n: m.n }).catch(() => {});   // the watchdog: this frame's renderer lives
        }
        break;
      case "focus":
        focusAutofocus();   // the engine handed this frame the keyboard: its autofocus field takes it
        break;
      case "text":
        // characters CEF's windowless mode cannot deliver as key events (Czech ě, Cyrillic Л ...): inserted at the caret, as typing
        // would (an input event follows; no keydown)
        focusAutofocus();
        if (typeof m.text === "string" && isEditable(deepActive())) {
          document.execCommand("insertText", false, m.text);
        }
        break;
      case "hello": {   // at every ready: who this page is and which feeds it may read
        if (surface !== null && m.surface && typeof m.surface === "object") {
          for (const key of ["id", "width", "height"]) {
            if (Number.isInteger(m.surface[key])) surface[key] = m.surface[key];
          }
        }
        assigned(m.component, m.contract);
        state.dev = m.dev === true;
        if (m.visibility && typeof m.visibility === "object") {
          state.visibility = m.visibility;
        }
        if (typeof m.playerCursor === "boolean" && m.playerCursor !== state.playerCursor) {
          state.playerCursor = m.playerCursor;   // (a page ready while the cursor is up hears it here: its handlers subscribed already)
          fire(handlers.playerCursor, state.playerCursor);
        }
        const listed = Array.isArray(m.feeds) ? m.feeds : [];
        for (const name of feedSubs.keys()) {
          if (!listed.includes(name)) log.warn(`the feed ${name} is not in this frame's manifest: it will get no data`);
        }
        break;
      }
      case "event":   // a mode's event the frame's events_in allows: the payload parsed when it is JSON, and as sent
        if (typeof m.name === "string") {
          fire(handlers.server.get(m.name), m.value, m.raw);
          fire(handlers.server.get("*"), m.value, m.raw, m.name);
        }
        break;
      case "feed":
        if (typeof m.name === "string") {
          feedLatest.set(m.name, m.data);
          fire(feedSubs.get(m.name), m.data);
        }
        break;
      case "visibility":
        state.visibility = m.data;
        fire(handlers.visibility, m.data);
        break;
      case "cursor":   // the player's cursor key: their cursor came up or went away
        if (typeof m.shown === "boolean" && m.shown !== state.playerCursor) {
          state.playerCursor = m.shown;
          fire(handlers.playerCursor, m.shown);
        }
        break;
      case "key":   // a key the mode bound (RegisterKeyBinding), as the player has it bound: to every ready frame, this one hears the names it asked for
        if (typeof m.name === "string") {
          fire(handlers.binding.get(m.name), m.pressed === true);
        }
        break;
      case "assign":   // the server (un)assigned a component to this frame: {component, contract}, component "" = none
        assigned(m.component, m.contract);
        if (m.component === "loading") {
          loadingShownSoon();   // (every assignment: the engine tells a page again after each of its readies)
        }
        break;
      case "component":   // one event of the component this frame draws: "chat:message" ...
        if (typeof m.name === "string" && NAME.test(m.name)) {
          componentEvent(m.name, m.data);
        }
        break;
      case "use":   // v83: the player pressed the use key on this surface (its prompt; the mode's OnPlayerUseWebSurface hears it too)
        fire(handlers.use);
        break;
      case "error": {   // the engine's word on this page: over a budget
        const error = new Error(typeof m.message === "string" ? m.message : "error");
        error.code = typeof m.code === "string" ? m.code : "";
        fire(handlers.error, error);
        break;
      }
      default:
        break;
    }
  }

  // native -> this frame: only from the root, with the root's origin (siblings cannot forge it, §8.4)
  if (inGame && !isRoot) {
    window.addEventListener("message", (e) => {
      if (e.source !== window.parent || e.origin !== ROOT_ORIGIN) {
        return;
      }
      const d = e.data;
      if (d !== null && typeof d === "object" && !Array.isArray(d) && d.__kcdmp && typeof d.__kcdmp === "object") {
        engineMessage(d.__kcdmp);
      } else {
        fire(handlers.message, d);   // client Lua's SendWebMessage and the mode's SendPlayerWebMessage, as sent
      }
    });
  }

  // native -> a surface's page (v83): the engine calls this in the page's own browser - a property no script can replace (the SDK is the
  // document's first script). The mode's SendWebSurfaceMessage as sent; the engine's own words wrapped in __kcdmp, which the server never
  // lets a mode send
  if (isSurface) {
    Object.defineProperty(window, "__kcdmp_surface_in", {
      value: (d) => {
        if (d !== null && typeof d === "object" && !Array.isArray(d) && d.__kcdmp && typeof d.__kcdmp === "object") {
          engineMessage(d.__kcdmp);
        } else {
          fire(handlers.message, d);
        }
      },
      writable: false,
      configurable: false,
      enumerable: false,
    });
  }

  // KcdMp.feed.<name> for any name: a page reads only the feeds its manifest lists
  const feedObjects = new Map();
  const feed = new Proxy(Object.create(null), {
    get(_, name) {
      if (typeof name !== "string") {
        return undefined;
      }
      if (!feedObjects.has(name)) {
        feedObjects.set(name, Object.freeze({
          subscribe(f) {
            if (!feedSubs.has(name)) feedSubs.set(name, new Set());
            const set = feedSubs.get(name);
            set.add(fn_(f));
            if (feedLatest.has(name)) fire([f], feedLatest.get(name));   // the last value at once
            return () => set.delete(f);
          },
        }));
      }
      return feedObjects.get(name);
    },
  });

  // @api property frame
  // @api property api
  // @api property contract
  // @api property env
  // @api property env.mock
  // @api property env.screen
  // @api property env.locale
  // @api property env.dev
  // @api property env.component
  // @api function ready
  // @api handler onMessage
  // @api function post
  // @api handler onServer
  // @api function emitServer
  // @api function call
  // @api property feed
  // @api handler feed.session.subscribe
  // @api handler feed.visibility.subscribe
  // @api function focus
  // @api function blur
  // @api handler onVisibility
  // @api handler onPlayerCursor
  // @api handler onKeyBinding
  // @api handler onComponent
  // @api handler onError
  // @api function itemIcon
  // @api property surface
  // @api handler onSurfaceUse
  const KcdMp = {
    frame,
    api: 1,
    get contract() { return state.contract; },
    env: Object.freeze({
      mock: !inGame,
      get screen() { return { w: window.innerWidth, h: window.innerHeight, scale: window.devicePixelRatio }; },
      get locale() { return navigator.language; },
      get dev() { return state.dev; },
      get component() { return state.component; },
    }),
    ready: () => call("sys", "ready", {}),
    // the value as SendWebMessage / SendPlayerWebMessage sent it
    onMessage: (f) => add(handlers.message, f),
    // client Lua's OnWebEvent answers: its return value (10 s at most)
    post: async (name, data) => call("post", name_(name), data),
    // a mode's event the frame's events_in allows: f(value, raw) - value is the payload parsed as JSON when it is JSON, raw the
    // text as sent; the name "*" hears every allowed event (f(value, raw, name))
    onServer: (name, f) => addTo(handlers.server, name === "*" ? name : name_(name), f),
    // to the game mode's OnClientEvent (source = this frame): a string goes as it is, anything else as JSON; the frame's events_out
    // and the player's budget of events (30 a second) apply
    emitServer: async (name, value) => call("emit", name_(name), value),
    // a component's action (Phase 5): "unknown action" until then
    call: async (action, data) => call("call", name_(action), data),
    feed,
    focus: (options) => {
      const o = options || {};
      const body = { keyboard: !!o.keyboard, cursor: !!o.cursor };
      if (o.keepInput !== undefined) body.keepInput = !!o.keepInput;
      return call("sys", "focus", body);
    },
    blur: () => call("sys", "blur", {}),
    // {visible, reason}: reason is "loading", "menu", "game_screen", "panic", "hidden" or "" while the layer draws
    onVisibility: (f) => {
      const off = add(handlers.visibility, f);
      fire([f], state.visibility);
      return off;
    },
    // the player's cursor (their cursor key, or a client script's SetCursorShown): f(shown) now and at every change. While it is up and no
    // frame holds the pointer, our own components take the clicks; a page that wants them takes the pointer itself -
    // KcdMp.focus({cursor: shown}) - and gives it back when the cursor goes
    onPlayerCursor: (f) => {
      const off = add(handlers.playerCursor, f);
      fire([f], state.playerCursor);
      return off;
    },
    // a key of the game mode's own (its RegisterKeyBinding; the player's own key for it, else the mode's default): f(pressed) on the press (true) and
    // the release (false). The game does not get the key while it is bound; it is never sent while a page holds the keyboard, the chat box or the
    // F9 window is open, or one of the game's own menus is up. A name the mode never declared is never heard
    onKeyBinding: (name, f) => addTo(handlers.binding, name_(name), f),
    // the events of the component this frame draws (the server assigned it with SetPlayerInterface; KcdMp.env.component and KcdMp.contract
    // say which): f(data, name) for one name ("chat:message", "roster:update" ...), for "*" every name, and for "assign" the assignment
    // itself, {component, contract} (component "" = none any more). The state events (STATE_EVENTS: the configs, the chat's lines, the
    // roster, the HUD texts, a GameText or a sleep's fade while it lasts, the death until death:hide, the party and its invitation, the
    // voice, the emote wheel while it is open, the shop and the dialog while open, the loading screen's state, handover and end) are
    // replayed to a handler that subscribes late, as they are now; the rest (chat:message, chat:open, notice:show ...) come as they happen
    onComponent: (name, f) => {
      const key = name === "*" ? name : name_(name);
      const off = addTo(handlers.component, key, f);
      if (state.component && (key === "*" || key === "assign")) {
        fire([f], { component: state.component, contract: state.contract }, "assign");
      }
      for (const event of key === "*" ? STATE_EVENTS : key === "assign" ? [] : [key]) {
        if (event === "shop:list") {
          for (const list of shopLists) if (list) fire([f], list, event);   // (one per tab)
          continue;
        }
        const data = replayOf(event);
        if (data !== undefined) fire([f], data, event);
      }
      return off;
    },
    onError: (f) => add(handlers.error, f),
    log,
    itemIcon,
    // v83: on a surface's page, {name, id, width, height} - the surface's page name (ui.toml), the entity id of the surface this copy
    // draws (0 until the engine's hello) and the page's pixels; null in a frame
    get surface() { return surface === null ? null : Object.freeze({ ...surface }); },
    // v83: the player pressed the use key on this surface (it has a prompt): f() - on that player's copy alone
    onSurfaceUse: (f) => add(handlers.use, f),
  };
  if (!inGame) {
    // Mock mode: outside the game every call resolves locally; these drive the page's handlers as the game would.
    // @api property mock
    // @api function mock.emit
    // @api function mock.message
    // @api function mock.feed
    // @api function mock.reply
    // @api function mock.key
    // @api function mock.playerCursor
    // @api function mock.component
    // @api function mock.use
    KcdMp.mock = Object.freeze({
      emit: (name, value) => {   // as if the mode sent the event
        const raw = stringify(value === undefined ? "" : value);
        fire(handlers.server.get(name_(name)), value, raw);
        fire(handlers.server.get("*"), value, raw, name);
      },
      message: (data) => fire(handlers.message, data),   // as if client Lua or the mode sent a message
      use: () => fire(handlers.use),                      // as if the player used the surface (onSurfaceUse)
      feed: (name, data) => {                             // as if the engine published a feed
        feedLatest.set(name, data);
        fire(feedSubs.get(name), data);
      },
      reply: (name, f) => { mockReplies.set(name, f); },  // what KcdMp.post(name, data) answers
      key: (name, pressed) => fire(handlers.binding.get(name_(name)), pressed !== false),   // as if the player pressed (or, with false, let go of) a bound key
      playerCursor: (shown) => {   // as if the player brought their cursor up (or, with false, took it away)
        state.playerCursor = shown !== false;
        fire(handlers.playerCursor, state.playerCursor);
      },
      // as if the engine sent the component's event ("chat:message", data ...); the name "assign" with {component, contract} is the assignment
      component: (name, data) => (name === "assign" ? assigned(data && data.component, data && data.contract) : componentEvent(name_(name), data)),
    });
  }
  Object.defineProperty(window, "KcdMp", { value: Object.freeze(KcdMp), writable: false, configurable: false, enumerable: true });

  // Esc gives the focus back unless the page kept it (preventDefault in its own handler). Decided once the event is over (2026-10-07): this
  // listener is the window's first, so a page's own window listener ran after the check and its preventDefault came too late
  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      setTimeout(() => {
        if (!e.defaultPrevented) {
          KcdMp.blur().catch(() => {});
        }
      }, 0);
    }
  });

  // The wheel (2026-10-10, a forum report: "the mouse wheel doesn't scroll a page's scrollbar"): the game's browser draws without a window,
  // and there the wheel's own scroll stays latched on the first box it ever scrolled - every wheel event reaches the element under the pointer,
  // but the scroll goes to that box (the lab frame: a wheel over an empty spot scrolled its list, and in a frame where the first wheel had
  // landed elsewhere the list heard "wheel 66" and stayed at scrollTop 0). So the SDK scrolls: a wheel no listener of the page took
  // (preventDefault, as the chat's and the shop's own wheels do) is taken here - the stray latched scroll with it - and the nearest box
  // under the pointer that can still move that way is scrolled, as the browser would; the document last, unless it hides its overflow.
  // A page's own window listener added after this one sees the wheel taken. Only in the game: a page outside it scrolls by itself.
  if (inGame) {
    const LINE = 40;   // a wheel counted in lines (deltaMode 1)
    const overflow = (el, axis) => (axis === "y" ? getComputedStyle(el).overflowY : getComputedStyle(el).overflowX);
    const opens = (el, axis) => /^(auto|scroll|overlay)$/.test(overflow(el, axis));
    const roomY = (el, dy) => (dy < 0 && el.scrollTop > 0) || (dy > 0 && el.scrollTop + el.clientHeight < el.scrollHeight - 1);
    const roomX = (el, dx) => (dx < 0 && el.scrollLeft > 0) || (dx > 0 && el.scrollLeft + el.clientWidth < el.scrollWidth - 1);
    window.addEventListener("wheel", (e) => {
      if (e.defaultPrevented || e.ctrlKey) {
        return;
      }
      e.preventDefault();
      const unit = e.deltaMode === 1 ? LINE : e.deltaMode === 2 ? window.innerHeight : 1;
      let dx = e.deltaX * unit;
      let dy = e.deltaY * unit;
      if (e.shiftKey && dx === 0) {
        [dx, dy] = [dy, 0];
      }
      const scroll = (el, mayY, mayX) => {
        const y = dy && mayY && roomY(el, dy) ? dy : 0;
        const x = dx && mayX && roomX(el, dx) ? dx : 0;
        if (x || y) {
          el.scrollBy(x, y);
        }
        return x !== 0 || y !== 0;
      };
      for (const node of e.composedPath()) {
        if (node instanceof Element && node !== document.documentElement && node !== document.body &&
            scroll(node, opens(node, "y"), opens(node, "x"))) {
          return;
        }
      }
      // the document: unless <html> or <body> hides that axis
      const shut = (axis) => [document.documentElement, document.body].some((el) => el && /^(hidden|clip)$/.test(overflow(el, axis)));
      if (document.scrollingElement) {
        scroll(document.scrollingElement, !shut("y"), !shut("x"));
      }
    }, { passive: false });
  }

  // the handshake (§8.5): on DOMContentLoaded unless the page says data-kcdmp-manual-ready on <html>
  if (!document.documentElement.hasAttribute("data-kcdmp-manual-ready")) {
    const go = () => { KcdMp.ready().catch((e) => log.warn(`ready: ${e && e.message}`)); };
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", go, { once: true });
    } else {
      go();
    }
  }
})();
