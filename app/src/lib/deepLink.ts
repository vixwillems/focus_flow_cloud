import { onOpenUrl } from '@tauri-apps/plugin-deep-link'
import { wsStore } from './ws'

/// Register a one-time listener for the `focusflow://break` deep link
/// emitted by the Live Activity's Break / Skip button. The handler
/// starts the WebSocket (no-op if already running) and waits up to
/// 2s for it to open before dispatching the `breakEvent` — without
/// the wait, a cold-start tap would hit `wsStore.send()` before the
/// socket is up and the event would be silently dropped.
///
/// If the user isn't logged in the WS never connects and the break
/// is lost; the user can then tap the Break button again from inside
/// the app, or just let the session run to its natural end. Same
/// limitation as the reminder poller in `+layout.svelte`.
let setup = false

export function setupDeepLinks() {
    if (setup) return
    setup = true
    void onOpenUrl((urls) => {
        for (const url of urls) {
            if (url === 'focusflow://break' || url.startsWith('focusflow://break')) {
                void dispatchBreak()
            }
        }
    })
}

async function dispatchBreak() {
    wsStore.start()
    const deadline = Date.now() + 2_000
    while (Date.now() < deadline && !wsStore.isConnected()) {
        await new Promise((r) => setTimeout(r, 50))
    }
    wsStore.send({ type: 'break' })
}
