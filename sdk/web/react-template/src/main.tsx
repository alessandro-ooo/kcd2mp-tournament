import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.tsx'
import './App.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)

// Outside the game (npm run dev, a browser) the SDK runs in mock mode: play the game mode's part so there is something to see.
if (KcdMp.env.mock && KcdMp.mock) {
  const mock = KcdMp.mock
  mock.feed('session', { server: 'My server', address: '127.0.0.1:7777', level: 'klaster', playerId: 0, name: 'Henry', rtt: 24 })
  setTimeout(() => mock.emit('panel.hello', { text: 'Hello from the game mode!', items: ['longSwordDuel', 'bread', 'apple'] }), 300)
}
