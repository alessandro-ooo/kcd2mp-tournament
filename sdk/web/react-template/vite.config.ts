import { existsSync, readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin, type PreviewServer, type ViteDevServer } from 'vite'

// The page SDK. index.html loads /__kcdmp/sdk.js: in the game the game itself answers that address - in your server's interface,
// and for this development server in UI developer mode. In a browser, this serves the copy next to this file (sdk.js, from the
// server folder's sdk/web/), and the page runs in mock mode.
function kcdmpSdk(): Plugin {
  const file = fileURLToPath(new URL('./sdk.js', import.meta.url))
  const serve = (server: ViteDevServer | PreviewServer) => {
    server.middlewares.use('/__kcdmp/sdk.js', (_req, res) => {
      res.setHeader('Content-Type', 'text/javascript; charset=utf-8')
      res.end(existsSync(file)
        ? readFileSync(file)
        : 'console.error("sdk.js is missing next to vite.config.ts: copy it from your server folder\'s sdk/web/")')
    })
  }
  return { name: 'kcdmp-sdk', configureServer: serve, configurePreviewServer: serve }
}

export default defineConfig({
  // the game serves the interface's files from the frame's own folder: every address in the build is relative
  base: './',
  plugins: [react(), kcdmpSdk()],
  build: {
    outDir: 'dist',
    // no file turned into a data: address - a page's fonts may come from its own files only
    assetsInlineLimit: 0,
  },
  server: {
    // UI developer mode loads a frame from http://127.0.0.1:<port> (not "localhost")
    host: '127.0.0.1',
    port: 5173,
    strictPort: true,
  },
})
