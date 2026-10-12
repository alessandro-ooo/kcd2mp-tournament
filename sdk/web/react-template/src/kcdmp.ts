// React hooks over the page SDK (window.KcdMp - its types are in KcdMp-web.d.ts next to this file). Each hook subscribes when the
// component mounts and takes the handler off again when it unmounts.
import { useEffect, useRef, useState } from 'react'

/** An event the game mode sends (SendClientEvent) whose name the frame's `events_in` allows: `handler(value)` for each one. */
export function useServerEvent<T = unknown>(name: string, handler: (value: T) => void): void {
  const latest = useRef(handler)
  latest.current = handler
  useEffect(() => KcdMp.onServer(name, (value) => latest.current(value as T)), [name])
}

/** A message for this frame alone (the mode's SendPlayerWebMessage, a client script's SendWebMessage). */
export function useMessage<T = unknown>(handler: (data: T) => void): void {
  const latest = useRef(handler)
  latest.current = handler
  useEffect(() => KcdMp.onMessage((data) => latest.current(data as T)), [])
}

/** A key the mode declared (RegisterKeyBinding): `handler(pressed)` on the press and the release. */
export function useKeyBinding(name: string, handler: (pressed: boolean) => void): void {
  const latest = useRef(handler)
  latest.current = handler
  useEffect(() => KcdMp.onKeyBinding(name, (pressed) => latest.current(pressed)), [name])
}

/** The session feed - the server, the level, the player and the ping - when the frame's `feeds` lists "session"; null until it comes. */
export function useSession(): KcdMpSessionFeed | null {
  const [session, setSession] = useState<KcdMpSessionFeed | null>(null)
  useEffect(() => KcdMp.feed.session.subscribe(setSession), [])
  return session
}
