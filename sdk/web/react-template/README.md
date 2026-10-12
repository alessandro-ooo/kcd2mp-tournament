# React + TypeScript starter for a KCD:MP web interface

A [Vite](https://vite.dev) project with React and TypeScript, set up for a KCD:MP server's web interface: one small panel (`src/App.tsx`)
that shows what the game mode sends, the item pictures of the player's game and two buttons that talk back to the mode. Replace the
panel with your own.

You need [Node.js](https://nodejs.org) (24 or newer) on the computer you build on - not on the server.

## Write

```sh
npm install
npm run dev
```

opens the panel at `http://127.0.0.1:5173/` in your browser. Outside the game the page SDK runs in **mock mode**: `src/main.tsx`
plays the game mode's part with made-up data, and item pictures are a placeholder square. The types of the whole `KcdMp` object
are in `src/KcdMp-web.d.ts` (your editor reads them); `src/kcdmp.ts` has React hooks for the events, messages, keys and feeds.

**In the game, while you write**: turn on **UI developer mode** in the launcher's settings and add
`-KcdMp_web_dev_url panel=http://127.0.0.1:5173/` to its **Game arguments**. The frame `panel` then loads from `npm run dev` on your
own PC, and every save shows in the game at once. Only servers on your own list can be joined in this mode.

## Build and put it on your server

```sh
npm run build
```

writes the panel to `dist/`. Then, for a mode called `myui`:

1. Copy `server/ui.toml` to `gamemodes/myui/ui/ui.toml`, and everything in `dist/` to `gamemodes/myui/ui/panel/`.
2. Copy `server/panel.lua` to `gamemodes/myui/myui.lua` (or take its calls into your own mode).
3. Set `[gamemode] script = "gamemodes/myui/myui.lua"` in `server.toml` and start the server. In the game, `/panel` shows the panel.

## Rules worth knowing

- `vite.config.ts` keeps every address in the build relative (`base: './'`): the game serves the files from the frame's folder.
- Pages run under a strict security policy: no inline `<script>`, no `eval`, nothing from other sites unless `ui.toml`'s
  `[permissions]` names the host. React's `onClick` and the build Vite makes are fine.
- What a page sends the mode is the player's game's word: check it on the server like any input from a player.
