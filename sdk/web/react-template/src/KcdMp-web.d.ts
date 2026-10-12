// KCD:MP (KCD Multiplayer) - the web interface SDK (a page's window.KcdMp).
// Type definitions for TypeScript and editors: completion, hover documentation and checking while writing a page.
// Generated from the reference - do not edit.
// https://docs.kcd-mp.com

/** The size of the page and of the display it is drawn on. */
interface KcdMpScreen {
  /** the page's width in CSS pixels */
  readonly w: number;
  /** the page's height in CSS pixels */
  readonly h: number;
  /** the display's pixel ratio (`2` on a display that draws two device pixels per CSS pixel) */
  readonly scale: number;
}

/** The connection and the player, as the `session` feed carries them. */
interface KcdMpSessionFeed {
  /** the server's name */
  readonly server: string;
  /** `host:port` as the player connected to it */
  readonly address: string;
  /** the level the server runs */
  readonly level: string;
  /** the player's id on the server - the game mode's `pid` */
  readonly playerId: number;
  /** the player's name */
  readonly name: string;
  /** the round-trip time to the server in milliseconds, `0` until it has been measured */
  readonly rtt: number;
}

/** Whether the interface is drawn, and if not, why. */
interface KcdMpVisibility {
  /** `true` while the interface is drawn over the game */
  readonly visible: boolean;
  /** why it is not drawn: `"loading"` (a level is loading), `"menu"` (a game menu is open), `"game_screen"` (one of the game's own screens is up), `"panic"` (the player switched the interface off), `"hidden"` (it is turned off), and `""` while it is drawn */
  readonly reason: "loading" | "menu" | "game_screen" | "panic" | "hidden" | "";
}

/** What a page asks for with `KcdMp.focus`. */
interface KcdMpFocusOptions {
  /** `true` to receive the keys (typed text goes to the page's text fields) */
  readonly keyboard?: boolean;
  /** `true` to receive the mouse cursor */
  readonly cursor?: boolean;
  /** `true` to let the game keep the player's keys while no text field of the page has the focus, so the player can walk with the page open */
  readonly keepInput?: boolean;
}

/** The surface a copy of a surface page is drawn on. */
interface KcdMpSurface {
  /** the page's name in `ui.toml` (`[surfaces.<name>]`) */
  readonly name: string;
  /** the surface's entity id - the id the game mode's `CreateWebSurface` returned; `0` until the page is ready */
  readonly id: number;
  /** the page's width in pixels (its `ui.toml` `width`) */
  readonly width: number;
  /** the page's height in pixels (its `ui.toml` `height`) */
  readonly height: number;
}

interface KcdMpEnv {
  /**
   * Whether the page runs outside the game.
   *
   * `true` when the page is opened in a plain browser - while it is being written, or in a test - and not in a player's game.
   * Every call then answers on the spot with a plain reply and `KcdMp.mock` drives the page's handlers.
   */
  readonly mock: boolean;
  /**
   * The size of the page and its display's pixel ratio.
   *
   * Read it when you need it: every read gives a fresh object with the size at that moment, so a page that adapts to its
   * size reads it again on a `resize` event.
   */
  readonly screen: KcdMpScreen;
  /**
   * The player's language, as a language tag.
   *
   * A tag such as `"en-US"` or `"cs"`, the language the player's game runs in.
   */
  readonly locale: string;
  /**
   * Whether the player's game runs in developer mode.
   *
   * `true` in a game that runs in developer mode, which is not how players run it; a page may show extra diagnostics there.
   * `false` in every other game, and outside the game.
   */
  readonly dev: boolean;
  /**
   * The game's interface component this frame draws, if any.
   *
   * The component's name (`"chat"`), or `""` for a frame that draws none. It goes with `KcdMp.contract`.
   */
  readonly component: string;
}

interface KcdMpFeedSession {
  /**
   * Registers a function that receives the connection and the player.
   *
   * `fn(session)` is called with the latest value at once when there is one, and again whenever it changes: when the player
   * has joined the server, and about every five seconds while the round-trip time moves. The value never holds anything that
   * is private to the player's game - it is the server's name and address, the level, and the player's id, name and ping.
   *
   * The frame must list `session` in its `feeds` in `ui.toml`.
   *
   * @param fn - called with each value
   * @returns a function that takes the handler off again
   */
  subscribe(fn: (session: KcdMpSessionFeed) => void): () => void;
}

interface KcdMpFeedVisibility {
  /**
   * Registers a function that is told when the interface is drawn or hidden.
   *
   * `fn({ visible, reason })` is called with the latest value at once and again whenever it changes. It is the same news as
   * `KcdMp.onVisibility` gives, from the feed's list: use the feed when the frame lists `visibility` in its `feeds`, the
   * handler when it does not.
   *
   * The frame must list `visibility` in its `feeds` in `ui.toml`.
   *
   * @param fn - called with each value
   * @returns a function that takes the handler off again
   */
  subscribe(fn: (visibility: KcdMpVisibility) => void): () => void;
}

interface KcdMpFeed {
  readonly session: KcdMpFeedSession;
  readonly visibility: KcdMpFeedVisibility;
}

interface KcdMpLog {
  /**
   * Writes a line to the interface log.
   *
   * The arguments are turned into text - a text as it is, anything else as JSON, or as `String(x)` when that fails - and
   * joined with spaces; a line is cut to 2000 characters.
   *
   * @param args - what to write
   */
  info(...args: unknown[]): void;
  /**
   * Writes a warning to the interface log.
   *
   * The same as `KcdMp.log.info`, marked as a warning.
   *
   * @param args - what to write
   */
  warn(...args: unknown[]): void;
  /**
   * Writes an error to the interface log.
   *
   * The same as `KcdMp.log.info`, marked as an error. When the server asked to hear the errors of its pages, the game
   * mode is told of it as well (with the text cut short, at most five a minute for a player).
   *
   * @param args - what to write
   */
  error(...args: unknown[]): void;
}

interface KcdMpMock {
  /**
   * Fires the page's event handlers as if the game mode had sent the event.
   *
   * Runs the handlers registered with `KcdMp.onServer` for `name` - and for `"*"` - with `value` and its text: a text is
   * its own text, anything else is written as JSON.
   *
   * @param name - the event's name
   * @param value - the payload
   */
  emit(name: string, value?: unknown): void;
  /**
   * Fires the page's message handlers as if a client script or the game mode had sent a message.
   *
   * Runs the handlers registered with `KcdMp.onMessage` with `data`, untouched.
   *
   * @param data - the message
   */
  message(data: unknown): void;
  /**
   * Publishes a feed value as if the game had.
   *
   * Runs the handlers subscribed to the feed with `data` and keeps it as the feed's latest value, which a later subscription
   * receives at once - exactly as in the game. Any feed name works: the frame's `feeds` list is not checked in mock mode.
   *
   * @param name - the feed's name (`"session"`, `"visibility"`)
   * @param data - the feed's value
   */
  feed(name: string, data: unknown): void;
  /**
   * Sets what `KcdMp.post` answers for a name.
   *
   * In mock mode `KcdMp.post(name, data)` calls `fn(data)` and resolves to what it returns (or to what a returned promise
   * resolves to), where in the game a client script's `OnWebEvent` would answer. A name without a reply answers
   * `{ ok: true, mock: true }`.
   *
   * @param name - the call's name
   * @param fn - answers the call
   */
  reply(name: string, fn: (data: unknown) => unknown): void;
  /**
   * Fires a key binding's handlers as if the player had pressed - or let go of - the key.
   *
   * Runs the handlers registered with `KcdMp.onKeyBinding` for `name` with `pressed`, as the game does when the player's key
   * for a binding of the game mode goes down or comes up. Any name works: in mock mode no server has declared the bindings.
   * A press and a release are two calls - `pressed` is `true` unless it says `false`.
   *
   * @param name - the binding's name
   * @param pressed - `true` for the press (the default), `false` for the release
   */
  key(name: string, pressed?: boolean): void;
  /**
   * Fires the player-cursor handlers as if the player had brought up - or taken away - their cursor.
   *
   * Runs the handlers registered with `KcdMp.onPlayerCursor` with `shown`, as the game does when the player's cursor key
   * brings the cursor up or takes it away; a handler registered later is told the same state. `shown` is `true` unless it
   * says `false`.
   *
   * @param shown - `true` for the cursor up (the default), `false` for it gone
   */
  playerCursor(shown?: boolean): void;
  /**
   * Fires the surface-use handlers as if the player had pressed the use key on the surface.
   *
   * Runs the handlers registered with `KcdMp.onSurfaceUse`, as the game does when the player uses a surface page's prompt -
   * a way to try a surface page's use in a browser. It works for a frame's page too, where nothing else would call them.
   */
  use(): void;
  /**
   * Plays an event of the component the page draws - or its assignment - as the game would.
   *
   * Runs the handlers registered with `KcdMp.onComponent` for `name` with `data`, and keeps what the game would keep: a
   * `chat:message` joins the lines a late handler of `chat:history` is told, a `roster:update` the roster. The name `"assign"`
   * with `{ component, contract }` gives the page a component (`{ component: "chat", contract: "chat@1" }`) or takes it away
   * (`{ component: "" }`), as the game mode's `SetPlayerInterface` does in the game. `KcdMp.call` answers
   * `{ ok: true, mock: true }` meanwhile, so a page can be tried with the whole contract in a browser.
   *
   * @param name - an event of the component's contract (`"chat:message"` ...), or `"assign"`
   * @param data - the event's data, as the contract describes it
   */
  component(name: string, data: unknown): void;
}

interface KcdMpApi {
  /**
   * The name of this page's frame.
   *
   * The name the interface's `ui.toml` gives the frame the page is drawn in (`"menu"`, `"scoreboard"`) - the name the game
   * mode and the client scripts use for it, and the `source` of the events the page sends. It is `""` outside the game, in
   * mock mode.
   */
  readonly frame: string;
  /**
   * The version of the page API the game runs.
   *
   * A whole number, `1`. It moves only when something a page relies on changes in a way old pages cannot follow; the
   * interface's `ui.toml` says which version it was written for (`api = 1`), and a page can check the one it actually got.
   */
  readonly api: number;
  /**
   * The contract this frame implements, when it draws one of the game's interface components.
   *
   * A frame can take over one of the game's own interface components - the chat, the scoreboard - from the standard
   * drawing; the component's **contract** is the list of events and actions such a frame must serve (`KcdMp.onComponent`).
   * This is its name and version (`"chat@1"`), or `""` for a frame that draws no component. It changes when the game mode
   * gives the frame a component or takes it away - `KcdMp.onComponent`'s `"assign"` says when.
   */
  readonly contract: string;
  /**
   * What the page knows about where it runs.
   *
   * A small read-only object: whether the game or a browser runs the page, the size of its screen, the player's language and
   * whether the game is in developer mode. Its members have their own pages.
   */
  readonly env: KcdMpEnv;
  /**
   * Tells the game the page is loaded and listening.
   *
   * Until it is called the game keeps everything addressed to the page - messages, events, feeds - and hands it over in
   * order once it is (up to 256 messages or 1 MB per frame; past that the oldest are dropped). The page's script calls it
   * by itself when the document has loaded; a page that has more to set up first says so in its `<html>` tag with the
   * attribute `data-kcdmp-manual-ready` and calls `KcdMp.ready()` when it is ready. The game mode's `OnPlayerWebReady`
   * and the client scripts' `OnWebFrameReady` run at that moment.
   *
   * A page that loads anew - the frame is made again, the interface changed - calls it again, and the queue and the feeds
   * start over for the new document.
   *
   * @returns settles once the game has taken it
   */
  ready(): Promise<void>;
  /**
   * Asks a client script something and waits for its answer.
   *
   * A client script of the server answers in its `OnWebEvent(frame, name, data)` callback; the value the callback returns is
   * what the promise resolves to, read from JSON. `data` is any JSON value (or nothing) of at most 16 KB.
   *
   * The promise **rejects** with an `Error` whose message says why: `"no handler"` when no client script answers,
   * `"handler failed"` when the script raised an error, `"timeout"` when no answer came within about ten seconds,
   * `"too many calls"` over the budget of about a hundred calls a second, and a text of the game's when the interface
   * reloaded or the game left the server while the call waited. A call never hangs.
   *
   * Use `KcdMp.emitServer` for the game mode: the mode's own answers come back as events or messages.
   *
   * @param name - what the call is, 1 to 64 characters of `a-z 0-9 _ . : -` - the script's `OnWebEvent` gets it as `name`
   * @param data - any JSON value
   * @returns the script's answer, read from JSON
   */
  post(name: string, data?: unknown): Promise<unknown>;
  /**
   * Sends the game mode an event.
   *
   * The event arrives in the mode's `OnClientEvent(pid, name, payload, source)` with the frame's name as `source`. `value` is
   * sent as it is when it is a text and as JSON when it is anything else (nothing sends an empty payload); it is at most
   * **16 KB**. The promise resolves once the game has sent the event - not when the mode has handled it.
   *
   * It **rejects** with an `Error` when the event cannot be sent: `"that event is not in the frame's events_out"` (the
   * name is not one the frame may send), `"too many events"` (the player is over their budget of 30 events and 64 KB a
   * second, shared with their client scripts), `"the payload is over 16 KB"`, `"not connected to a server"`.
   *
   * The mode treats what a page sends like any other input from a player: `source` says which frame sent it, and nothing more.
   *
   * @param name - the event's name, 1 to 64 characters of `a-z 0-9 _ . : -`; not one that starts with `kcdmp:`
   * @param value - the payload - a text as it is, anything else as JSON
   * @returns settles once the game has sent the event
   */
  emitServer(name: string, value?: unknown): Promise<void>;
  /**
   * Calls an action of the game's interface component this frame draws.
   *
   * A frame that draws one of the game's components in place of the standard drawing - the chat, for one - can call the
   * component's **actions** (`"chat.send"`): what the component does through the game itself. The actions of each component
   * are part of its contract (`KcdMp.onComponent` lists the chat's and the scoreboard's), and an action is available to
   * that frame alone, while it draws the component. An action that needs the player's own input (buying, answering a
   * dialogue) is refused unless a real key or click reached the frame in the last second.
   *
   * Any other action name - and any name from a frame that draws no component - rejects with `"unknown action"`; wrong data
   * rejects with what is wrong with it, a `chat.send` while the chat's box is closed with `"the chat box is not open"`, and
   * more than four lines a second with `"too many lines"`.
   *
   * @param action - the action's name, as its component's contract gives it
   * @param data - the action's arguments, any JSON value
   * @returns the action's answer, read from JSON
   */
  call(action: string, data?: unknown): Promise<unknown>;
  /**
   * Registers a function that receives what a client script or the game mode sent this frame with a message.
   *
   * `fn(data)` is called with **exactly the value** that was sent - a client script's `SendWebMessage(frame, data)` or the
   * mode's `SendPlayerWebMessage(pid, frame, data)`: a table arrives as an object or an array, a text as a text, and a page
   * never receives a message that only looks like the game's own. Messages arrive in the order they were sent, and one
   * sent before the page called `KcdMp.ready` is kept and delivered when it does. Any number of functions may be
   * registered; each gets every message, and one that throws is logged and does not stop the others.
   *
   * @param fn - called with each message
   * @returns a function that takes the handler off again
   */
  onMessage(fn: (data: unknown) => void): () => void;
  /**
   * Registers a function that receives the game mode's events with a given name.
   *
   * The game mode's `SendClientEvent(pid, name, payload)` - and `SendClientEventToAll` - reaches every page whose
   * `events_in` in `ui.toml` lets it receive `name`. `fn(value, raw)` is called with `value`, the payload read as JSON when it
   * is JSON (a table the mode sent arrives as an object or an array), or the text itself when it is not, and `raw`, the payload
   * exactly as a text.
   *
   * The name `"*"` hears every event the frame may receive; `fn` then gets the event's name as a third argument. Events
   * arrive in the order they were sent, and one sent before the page called `KcdMp.ready` is kept and delivered when it
   * does. An event the frame's `events_in` does not list never arrives.
   *
   * @param name - the event's name (1 to 64 characters of `a-z 0-9 _ . : -`), or `"*"` for every event the frame may receive
   * @param fn - called with each event; `name` is only there for `"*"`
   * @returns a function that takes the handler off again
   */
  onServer(name: string, fn: (value: unknown, raw: string, name: string) => void): () => void;
  /**
   * The feeds a page may read.
   *
   * `KcdMp.feed.session` and `KcdMp.feed.visibility` are the two feeds; each has a `subscribe` function. Only the feeds a
   * frame's `feeds` list in `ui.toml` names deliver values.
   */
  readonly feed: KcdMpFeed;
  /**
   * Asks the game to give this frame the keyboard and the mouse cursor.
   *
   * Neither `keyboard` nor `cursor` is the same as `KcdMp.blur`. With `keepInput` the frame holds the keyboard without
   * shutting the game's out: the game still gets the player's keys while no text field of the page has the focus.
   *
   * Whether the frame gets what it asked for is decided by its `focus` setting in `ui.toml`: `"never"` refuses everything,
   * `"input"` (the default) grants the cursor at once and the keyboard only within five seconds of the player's own click
   * or key press in the frame, `"open"` grants the cursor at any time and the keyboard at once together with it (the keyboard
   * alone after the player's first click in the frame).
   *
   * The promise **rejects** with an `Error` that says why when the request is refused: `"the frame's focus policy is
   * never"`, `"the keyboard comes with the player's click in the frame"` (a request for the keyboard the player has not
   * made a click or key press for), `"too many keyboard requests without the player's input"`, `"the frame is hidden"`
   * and `"the web layer is not running"`.
   *
   * @param options - what the page asks for; leave it out, or leave both `keyboard` and `cursor` off, to give the focus up
   * @returns settles when the game has answered; rejects when the request is refused
   */
  focus(options?: KcdMpFocusOptions): Promise<void>;
  /**
   * Gives the keyboard and the mouse cursor back to the game.
   *
   * The frame gives up what it holds: the game's keys and mouse work again. The page's script calls it itself when the
   * player presses Esc, unless the page's own key handler kept the key with `preventDefault()`.
   *
   * @returns settles when the game has answered
   */
  blur(): Promise<void>;
  /**
   * Registers a function that is told when the interface is drawn or hidden.
   *
   * `fn({ visible, reason })` is called at once with the current state, then again at every change. `visible` is `false` while
   * the interface is not drawn over the game, and `reason` says why: `"loading"` while a level loads, `"menu"` while a game menu
   * is open, `"game_screen"` while one of the game's own screens is up, `"panic"` after the player switched the interface off,
   * `"hidden"` while it is turned off, and `""` while it is drawn. A page that plays sound or animation can pause it meanwhile.
   *
   * @param fn - called with the state
   * @returns a function that takes the handler off again
   */
  onVisibility(fn: (visibility: KcdMpVisibility) => void): () => void;
  /**
   * Registers a function that is told when the player brings up their cursor or takes it away.
   *
   * The player brings up their cursor with the cursor key held for a second (left Alt unless they picked another in the
   * launcher), a client script with its `SetCursorShown` and the game mode with its `SetPlayerCursor`. `fn(shown)` is called at once with the current state, then again at every change. While
   * the cursor is up and no frame holds the mouse cursor, the interface's own parts (the chat, the scoreboard ...) take the
   * clicks; a page that wants them asks for the cursor itself - `KcdMp.focus({ cursor: true })` - and gives it back when the
   * player's cursor goes. The cursor goes away by itself when one of the game's own menus opens and at a load.
   *
   * @param fn - called with `true` while the cursor is up, `false` while it is not
   * @returns a function that takes the handler off again
   */
  onPlayerCursor(fn: (shown: boolean) => void): () => void;
  /**
   * Registers a function for a key binding the server declared.
   *
   * A **key binding** is a named key the game mode declared with its `RegisterKeyBinding`: it starts on the mode's default
   * key, and a player can put it on another with the command `KcdMp_bind` in the game's F9 window - when the server has
   * opened that window to its players (it is closed by default). `fn(pressed)` is called with `true` when
   * the key goes down and `false` when it comes up, on whichever key the player has it. The name is the binding's name as the
   * mode declared it - a name is 1 to 64 characters of `a-z 0-9 _ . : -`, and the mode's are at most 32.
   *
   * Every frame of the interface that is ready hears every press; each handler is called only for the name it asked for. The
   * handler only ever runs for a binding the mode has declared: until then the registration is harmless and silent. The game
   * does not get the key while it is bound, and a press is never delivered while a page holds the keyboard, the chat box or the
   * F9 window is open, or one of the game's own menus is up. A key that went down always gets its release. A page that
   * was not ready when the key went down hears nothing of it, and a press over the frame's message budget is dropped like any
   * other message - a release never is.
   *
   * @param name - the binding's name
   * @param fn - called on the key's press and release
   * @returns a function that takes the handler off again
   */
  onKeyBinding(name: string, fn: (pressed: boolean) => void): () => void;
  /**
   * Registers a function that receives the events of the game component this frame draws.
   *
   * `fn(data, name)` is called for every event named `name` of the component the frame draws - the tables above list them -
   * for `"*"` with every event, and for `"assign"` when the frame is given a component or loses it, with
   * `{ component, contract }` (`component` is `""` when it draws none any more; `KcdMp.env.component` and `KcdMp.contract`
   * change with it). A handler registered while the frame draws a component is told the assignment at once.
   *
   * The events that describe a **state** - `chat:config`, `chat:history`, `server:info`, `scoreboard:columns`,
   * `scoreboard:show`, `roster:snapshot`, `hudtext:snapshot`, `gametext:show`, `sleep:slept`, `death:show`, `party:config`,
   * `party:state`, `party:vitals`, `party:invite`, `voice:self`, `voice:talking`, `voice:muted`, `voice:levels`, `emotes:list`, `emotes:open`,
   * `emotes:pointer`, `shop:open`, `shop:list` (each tab's), `shop:state`, `player:purse`, `dialog:open`, `dialog:cursor`,
   * `loading:state`, `loading:handover` and `loading:end` - are kept by the page's `KcdMp` and handed to a handler that
   * registers late, as they are now: `chat:history` with the lines that arrived since and without the ones a clear took away,
   * `roster:snapshot` and `hudtext:snapshot` with the updates applied, a GameText, a sleep's fade or an invitation only while it
   * lasts (its `remainingMs`, `elapsedMs` or `seconds` moved on), `death:show` until `death:hide`, the wheel until
   * `emotes:close`, the shop until `shop:close`, a dialog until `dialog:close`. The others - a line, an open, a scroll, a notice
   * - are only ever told as they happen. When the frame loses the component, what was kept is forgotten.
   *
   * @param name - an event's name (`"chat:message"`), `"*"` for all of them, or `"assign"`
   * @param fn - called with each event's data and its name
   * @returns a function that takes the handler off again
   */
  onComponent(name: string, fn: (data: unknown, name: string) => void): () => void;
  /**
   * The address of an item's picture, for an `<img>` or a CSS background.
   *
   * `key` is the item class's GUID or its game name (`"longSwordDuel"`, in any case) - the `class` and the `name` a game
   * mode's `GetItemInfo` gives; the numeric id is the server's own and does not work here. The picture is the game's
   * inventory icon, 64 by 64 pixels on a transparent background; size it with CSS. An item without a picture, or a key the
   * game does not know, fails to load like any missing image: the `<img>`'s `error` event fires.
   *
   * The address is the same in every player's game, so a stylesheet may use it too
   * (`https://ui.kcd-mp.invalid/icons/items/<key>.png`). In a browser, in mock mode, every valid key gives a plain
   * placeholder square. A key of another shape gives `""`.
   *
   * @param key - the item class's GUID or game name
   * @returns the picture's address, or `""` when `key` is neither a GUID nor a name
   */
  itemIcon(key: string): string;
  /**
   * The surface this page is drawn on - or `null` in a frame.
   *
   * On a surface page, its surface: `name` (the page's name in `ui.toml`), `id` (the entity id the game mode knows it by, so
   * the page can tell the mode which board it is - the mode's surface callbacks are given it too) and the page's size in pixels.
   * Every surface the mode places with this page draws its own copy of it, so `id` is what tells the copies apart. `id` is `0`
   * until the page is ready - read it in a handler, or after `KcdMp.ready` answered. `null` in a frame's page and outside the
   * game.
   */
  readonly surface: KcdMpSurface | null;
  /**
   * Registers a function for the player's use key on this surface.
   *
   * A surface the game mode gave a use prompt (`CreateWebSurface`'s `prompt` option, or `SetEntityPrompt`) shows it in the
   * game's own use hint when a player looks at the surface from close by; their use key then calls `fn()` - on that player's
   * copy of the page alone - and the mode's `OnPlayerUseWebSurface`. A page uses it for what only that player should see (the
   * next page of a book, the next notice), and tells the mode what it needs to know with `KcdMp.emitServer`.
   *
   * @param fn - called at each use
   * @returns a function that takes the handler off again
   */
  onSurfaceUse(fn: () => void): () => void;
  readonly log: KcdMpLog;
  /**
   * Registers a function that is told of the page's errors and of the game's complaints about the page.
   *
   * `fn(error)` is called with an `Error` for each uncaught script error and each unhandled promise rejection of the page,
   * and for the game's own complaints about it: when messages toward the page were dropped because more arrived at once than
   * the game delivers (256 KB a second), the error's `code` is `"budget"`; the other errors have no `code`. One handler that
   * throws is logged and does not stop the rest.
   *
   * @param fn - called with each error
   * @returns a function that takes the handler off again
   */
  onError(fn: (error: Error) => void): () => void;
  /**
   * The controls that play the game's part when the page runs in a browser.
   *
   * Present only when `KcdMp.env.mock` is `true`. Its functions fire the page's own handlers as the game would:
   * `KcdMp.mock.emit` for the game mode's events, `KcdMp.mock.message` for messages, `KcdMp.mock.feed` for feeds,
   * `KcdMp.mock.reply` for the answers of client scripts, `KcdMp.mock.key` for the keys the game mode declared, and
   * `KcdMp.mock.component` for the events of a component the page draws.
   */
  readonly mock?: KcdMpMock;
}

/** The page's connection to the game: `window.KcdMp`. */
declare const KcdMp: KcdMpApi;

interface Window {
  readonly KcdMp: KcdMpApi;
}
