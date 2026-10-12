// A small panel to start from: what the game mode sent, the player's name and ping, three item pictures, and two buttons that talk
// back to the mode. Replace it with your own; kcdmp.ts has the hooks.
import { useState } from 'react'
import { useServerEvent, useSession } from './kcdmp.ts'

type Hello = { text: string; items: string[] }

export default function App() {
  const session = useSession()
  const [hello, setHello] = useState<Hello | null>(null)
  const [clicks, setClicks] = useState(0)

  // the mode's SendClientEvent(pid, "panel.hello", { text = ..., items = {...} }) - ui.toml's events_in lets it through
  useServerEvent<Hello>('panel.hello', setHello)

  const ping = () => {
    setClicks((n) => n + 1)
    KcdMp.emitServer('panel.ping', { clicks: clicks + 1 }).catch((e: Error) => KcdMp.log.warn('panel.ping: ' + e.message))
  }
  const close = () => {
    KcdMp.emitServer('panel.close').catch(() => {})
  }

  return (
    <section className="panel">
      <header>
        <h1>My panel</h1>
        <button className="close" type="button" aria-label="Close" onClick={close}>×</button>
      </header>
      <p className="who">
        {session ? `${session.name} on ${session.server} - ${session.rtt} ms` : 'Waiting for the game...'}
      </p>
      <p className="hello">{hello ? hello.text : 'Nothing from the game mode yet.'}</p>
      <ul className="items">
        {(hello?.items ?? []).map((item) => (
          <li key={item}>
            {/* the game's own picture of the item: every player's game makes it from its own files */}
            <img src={KcdMp.itemIcon(item)} alt={item} width={64} height={64} />
          </li>
        ))}
      </ul>
      <button type="button" onClick={ping}>Send the mode an event ({clicks})</button>
    </section>
  )
}
