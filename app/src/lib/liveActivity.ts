import { invoke } from '@tauri-apps/api/core'

const STORAGE_KEY = 'ff_live_activity_enabled'

function readEnabled(): boolean {
    if (typeof localStorage === 'undefined') return true
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === null) return true
    return stored === '1' || stored === 'true'
}

function writeEnabled(enabled: boolean) {
    if (typeof localStorage === 'undefined') return
    localStorage.setItem(STORAGE_KEY, enabled ? '1' : '0')
}

export type LivePhase = 'work' | 'shortBreak' | 'longBreak'

export function isTauriIOS(): boolean {
    if (typeof navigator === 'undefined') return false
    const platform = (navigator as Navigator & { userAgentData?: { platform: string } }).userAgentData?.platform
    if (platform) return platform === 'iOS' || platform === 'iPadOS'
    return /iPhone|iPad|iPod/i.test(navigator.userAgent || '')
}

// Per-page cache. We intentionally do NOT cache `false` across page mounts —
// the first call (right after the user installs or relaunches the app) can
// run before the Rust dylib / Swift runtime have fully initialized, and we
// don't want that transient miss to lock the toggle off for the whole
// session. `cachedTrue` is module-scoped (lives for the page lifetime);
// `cachedFalseFor` is also module-scoped and short, so the same page gets
// one retry on transient failures.
let cachedTrue = false
let cachedFalseUntil = 0
const FALSE_CACHE_MS = 30_000

export async function liveActivityAvailable(): Promise<boolean> {
    if (cachedTrue) return true
    const now = Date.now()
    if (now < cachedFalseUntil) return false
    if (!isTauriIOS()) {
        cachedFalseUntil = now + FALSE_CACHE_MS
        return false
    }
    try {
        const ok = await invoke<boolean>('live_activity_is_available')
        if (ok) {
            cachedTrue = true
            return true
        }
        cachedFalseUntil = now + FALSE_CACHE_MS
        return false
    } catch {
        cachedFalseUntil = now + FALSE_CACHE_MS
        return false
    }
}

// Used by the timer page right before it starts a Live Activity: if we
// already know the symbol is missing, surface the error to the JS side
// rather than silently calling into a no-op. (The symbol table on a
// freshly installed / re-built app may not yet be ready when the user
// first opens Settings.)
export function resetLiveActivityCache() {
    cachedTrue = false
    cachedFalseUntil = 0
}

export function liveActivityUserEnabled(): boolean {
    return readEnabled()
}

export function setLiveActivityUserEnabled(enabled: boolean) {
    writeEnabled(enabled)
    if (isTauriIOS()) {
        invoke('live_activity_set_enabled', { enabled }).catch(() => {})
    }
}

export async function startLiveActivity(opts: {
    sessionId: string
    phase: LivePhase
    totalSeconds: number
    taskName?: string | null
}) {
    if (!liveActivityUserEnabled()) return false
    if (!(await liveActivityAvailable())) return false
    try {
        return await invoke<boolean>('live_activity_start', {
            sessionId: opts.sessionId,
            phase: opts.phase,
            totalSeconds: opts.totalSeconds,
            taskName: opts.taskName ?? null,
        })
    } catch {
        return false
    }
}

export async function updateLiveActivity(opts: {
    secondsRemaining: number
    isPaused: boolean
    phase: LivePhase
    taskName?: string | null
}) {
    if (!liveActivityUserEnabled()) return false
    if (!(await liveActivityAvailable())) return false
    try {
        return await invoke<boolean>('live_activity_update', {
            secondsRemaining: opts.secondsRemaining,
            isPaused: opts.isPaused,
            phase: opts.phase,
            taskName: opts.taskName ?? null,
        })
    } catch {
        return false
    }
}

export async function endLiveActivity() {
    if (!(await liveActivityAvailable())) return
    try {
        await invoke<boolean>('live_activity_end')
    } catch {
        /* ignore */
    }
}
