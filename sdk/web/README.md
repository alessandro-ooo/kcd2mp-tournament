# Web interface examples and starter

Everything here is for making a **web interface** for your server: pages of HTML, CSS and JavaScript that every player's game
draws over the game. The guide **Make a web interface** on [docs.kcd-mp.com](https://docs.kcd-mp.com) explains the whole thing;
these are working pieces to start from.

| Folder | What it shows |
|---|---|
| `examples/replace-chat/` | A chat of your own: a page draws the game's chat - its lines, channels, command suggestions - instead of KCD:MP's |
| `examples/scoreboard/` | A scoreboard of your own, with columns the game mode adds (kills, deaths, time played) and a mute button per player |
| `examples/inventory/` | A window the mode opens with a key: what the player carries, drawn with the game's own item pictures |
| `examples/theme/` | No page at all: KCD:MP's own chat and scoreboard, moved and restyled by a stylesheet and a few colours |
| `examples/notice-board/` | Pages on boards in the world: a notice board players read with the use key, a tavern sign and a name painted on a wall (a see-through board), all hung on the wall you look at (a client script finds it) |
| `react-template/` | A starter for building pages with React, TypeScript and Vite |
| `sdk.js` | The page SDK, for trying a page in an ordinary browser (below) |

## Running an example

Each example is a small game mode (`<name>.lua`) with its interface in `ui/` next to it. Point the server at the mode in
`server.toml` and start it:

```toml
[gamemode]
script = "sdk/web/examples/inventory/inventory.lua"
```

Or copy the example's folder into `gamemodes/` and point `script` there. Join, and the interface is there; the start of each
`.lua` says what to press.

## Trying a page in a browser

Open a page's `index.html` in your browser (or serve the example's `ui/` folder with any local web server). The page loads
`../sdk.js` first, and outside the game the SDK runs in **mock mode**: every call answers on the spot, and the example feeds
itself some made-up data so you can see it and work on its look. In the game the copy steps aside for the game's own SDK.
Item pictures are a placeholder square in a browser - the real ones come from each player's game.

## Your own pages

- Every page follows the **rules for pages** in the guide: scripts in files (no inline `<script>`, no `onclick="..."`), no
  `eval`, and nothing from other sites unless `ui.toml` declares it.
- `KcdMp-web.d.ts` in `sdk/` has the types of the whole `KcdMp` object, for TypeScript and for editors.
- In the game, **UI developer mode** (the launcher's settings) gives you the pages' console in the F9 window and can load a frame
  from a development server on your own PC.
