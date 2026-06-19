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

let cachedAvailable: boolean | null = null
export async function liveActivityAvailable(): Promise<boolean> {
    if (cachedAvailable !== null) return cachedAvailable
    if (!isTauriIOS()) {
        cachedAvailable = false
        return false
    }
    try {
        cachedAvailable = await invoke<boolean>('live_activity_is_available')
    } catch {
        cachedAvailable = false
    }
    return cachedAvailable
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
