<script lang="ts">
    import { createQuery, createMutation } from "@tanstack/svelte-query";
    import { goto } from "$app/navigation";
    import { users as usersApi, auth as authApi, settings as settingsApi, ApiError } from "$lib/api";
    import { authStore } from "$lib/stores/auth";
    import { themeStore, THEMES, type Theme } from "$lib/stores/theme";
    import { serverUrlStore } from "$lib/stores/serverUrl";
    import type { UserSettingDto } from "@/types";
    import SettingsSection from "@/components/settings/SettingsSection.svelte";
    import {
        isTauriIOS,
        liveActivityAvailable,
        liveActivityUserEnabled,
        liveActivityDiagnostics,
        setLiveActivityUserEnabled,
    } from "$lib/liveActivity";

    const meQuery = createQuery({ queryKey: ["me"], queryFn: usersApi.me });

    const settingsQuery = createQuery({
        queryKey: ["settings"],
        queryFn: settingsApi.getAll,
    });

    let pomodoroWork = $state(50);
    let pomodoroShortBreak = $state(10);
    let pomodoroLongBreak = $state(20);
    let pomodoroOk = $state(false);

    $effect(() => {
        const s = $settingsQuery.data;
        if (!s) return;
        const get = (key: string, fallback: number) => {
            const found = s.find((x: UserSettingDto) => x.key === key);
            return found ? parseInt(found.value, 10) : fallback;
        };
        pomodoroWork = get("pomodoro_work_duration", 50);
        pomodoroShortBreak = get("pomodoro_short_break_duration", 10);
        pomodoroLongBreak = get("pomodoro_long_break_duration", 20);
    });

    const updatePomodoroDurations = createMutation({
        mutationFn: async () => {
            await settingsApi.update("pomodoro_work_duration", String(pomodoroWork));
            await settingsApi.update("pomodoro_short_break_duration", String(pomodoroShortBreak));
            await settingsApi.update("pomodoro_long_break_duration", String(pomodoroLongBreak));
        },
        onSuccess: () => {
            pomodoroOk = true;
            setTimeout(() => (pomodoroOk = false), 2000);
        },
    });

    let serverUrl = $state(serverUrlStore.get())
    let serverUrlOk = $state(false)

    function saveServerUrl() {
        if (!serverUrl.trim()) return
        serverUrlStore.set(serverUrl.trim())
        serverUrlOk = true
        setTimeout(() => (serverUrlOk = false), 2000)
    }

    let newUsername = $state("");
    let oldPassword = $state("");
    let newPassword = $state("");
    let usernameError = $state<string | null>(null);
    let passwordError = $state<string | null>(null);
    let usernameOk = $state(false);
    let passwordOk = $state(false);

    const updateUsername = createMutation({
        mutationFn: () =>
            usersApi.updateUsername({ new_username: newUsername }),
        onSuccess: () => {
            usernameOk = true;
            usernameError = null;
            newUsername = "";
        },
        onError: (e) => {
            usernameError = e instanceof ApiError ? e.message : "Failed";
            usernameOk = false;
        },
    });

    const updatePassword = createMutation({
        mutationFn: () =>
            usersApi.updatePassword({
                old_password: oldPassword,
                new_password: newPassword,
            }),
        onSuccess: () => {
            passwordOk = true;
            passwordError = null;
            oldPassword = "";
            newPassword = "";
        },
        onError: (e) => {
            passwordError = e instanceof ApiError ? e.message : "Failed";
            passwordOk = false;
        },
    });

    async function handleLogout() {
        await authApi.logout().catch(() => {});
        authStore.logout();
        goto("/login");
    }

    // Live Activity / Dynamic Island toggle (iOS only, client-side only).
    let liveActivityEnabled = $state(liveActivityUserEnabled());
    let liveActivityAvailableState = $state(false);
    let liveActivityOnIOS = $state(false);
    let liveActivityDiag = $state("");

    $effect(() => {
        liveActivityOnIOS = isTauriIOS();
        if (!liveActivityOnIOS) return;
        liveActivityAvailable().then((v) => (liveActivityAvailableState = v));
        liveActivityDiagnostics().then((s) => (liveActivityDiag = s));
    });

    function refreshLiveActivityDiag() {
        if (!liveActivityOnIOS) return;
        liveActivityAvailable().then((v) => (liveActivityAvailableState = v));
        liveActivityDiagnostics().then((s) => (liveActivityDiag = s));
    }

    function toggleLiveActivity() {
        liveActivityEnabled = !liveActivityEnabled;
        setLiveActivityUserEnabled(liveActivityEnabled);
    }
</script>

<div class="flex-1 min-h-0 flex flex-col overflow-hidden">
    <div class="flex-1 overflow-y-auto pb-24 px-4 pt-3">
        <SettingsSection title="Server">
            <label class="label mb-3">
                <span class="label-text text-xs font-mono tracking-widest uppercase text-surface-400">
                    Server URL
                </span>
                <input
                    class="input"
                    bind:value={serverUrl}
                    placeholder="https://api.example.com"
                    type="url"
                />
            </label>
            {#if serverUrlOk}
                <aside class="alert preset-tonal-success mb-2">
                    <p class="alert-message text-xs">Server URL updated!</p>
                </aside>
            {/if}
            <button
                onclick={saveServerUrl}
                disabled={!serverUrl.trim()}
                class="btn preset-filled-primary-500 text-sm disabled:opacity-50"
            >
                Save
            </button>
        </SettingsSection>

        <SettingsSection title="Appearance">
            <label class="label">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >Theme</span
                >
                <select
                    class="select capitalize"
                    value={$themeStore}
                    onchange={(e) =>
                        themeStore.setTheme(
                            (e.target as HTMLSelectElement).value as Theme,
                        )}
                >
                    {#each THEMES as t (t)}
                        <option value={t} class="capitalize">{t}</option>
                    {/each}
                </select>
            </label>
        </SettingsSection>

        <SettingsSection title="Pomodoro Timer">
            <p class="text-xs text-surface-400 mb-3">
                Default durations in minutes.
            </p>
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >Work</span
                >
                <input class="input" type="number" min="1" bind:value={pomodoroWork} />
            </label>
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >Short Break</span
                >
                <input class="input" type="number" min="1" bind:value={pomodoroShortBreak} />
            </label>
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >Long Break</span
                >
                <input class="input" type="number" min="1" bind:value={pomodoroLongBreak} />
            </label>
            {#if pomodoroOk}
                <aside class="alert preset-tonal-success mb-2">
                    <p class="alert-message text-xs">Durations saved!</p>
                </aside>
            {/if}
            <button
                onclick={() => $updatePomodoroDurations.mutate()}
                class="btn preset-filled-primary-500 text-sm"
            >
                Save
            </button>
        </SettingsSection>

        {#if liveActivityOnIOS}
            <SettingsSection title="Live Activity (iOS)">
                <p class="text-xs text-surface-400 mb-3">
                    Show your focus timer on the Lock Screen, in the Dynamic Island,
                    and as a Home Screen / StandBy widget.
                </p>
                {#if !liveActivityAvailableState}
                    <p class="text-xs text-warning-400 mb-3">
                        Live Activities are not available on this device or have been
                        disabled for FocusFlow in Settings → FocusFlow.
                    </p>
                {/if}
                <label class="flex items-center gap-3 cursor-pointer">
                    <input
                        type="checkbox"
                        class="checkbox"
                        checked={liveActivityEnabled}
                        onchange={toggleLiveActivity}
                    />
                    <span class="text-sm text-surface-100">
                        Show focus timer in Live Activity
                    </span>
                </label>
                {#if liveActivityDiag}
                    <details class="mt-3">
                        <summary class="text-xs text-surface-500 cursor-pointer select-none">
                            Diagnostic
                        </summary>
                        <pre
                            class="mt-2 p-2 rounded bg-surface-900 border border-surface-700 text-[10px] text-surface-300 font-mono whitespace-pre-wrap break-all">{liveActivityDiag}</pre>
                        <button
                            class="mt-2 btn btn-sm preset-tonal-surface text-xs"
                            onclick={refreshLiveActivityDiag}
                        >
                            Refresh
                        </button>
                    </details>
                {/if}
            </SettingsSection>
        {/if}

        <SettingsSection title="Account">
            <p class="text-xs text-surface-400 mb-3">
                Signed in as <strong class="text-surface-100 font-medium"
                    >{$meQuery.data?.username ?? "…"}</strong
                >
            </p>
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >New username</span
                >
                <input
                    class="input"
                    bind:value={newUsername}
                    placeholder="Enter new username"
                />
            </label>
            {#if usernameError}
                <aside class="alert preset-tonal-error mb-2">
                    <p class="alert-message text-xs">{usernameError}</p>
                </aside>
            {/if}
            {#if usernameOk}
                <aside class="alert preset-tonal-success mb-2">
                    <p class="alert-message text-xs">Username updated!</p>
                </aside>
            {/if}
            <button
                onclick={() => newUsername.trim() && $updateUsername.mutate()}
                disabled={!newUsername.trim()}
                class="btn preset-filled-primary-500 text-sm disabled:opacity-50"
            >
                Update Username
            </button>
        </SettingsSection>

        <SettingsSection title="Change Password">
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >Current password</span
                >
                <input
                    class="input"
                    type="password"
                    bind:value={oldPassword}
                    placeholder="••••••••"
                />
            </label>
            <label class="label mb-3">
                <span
                    class="label-text text-xs font-mono tracking-widest uppercase text-surface-400"
                    >New password</span
                >
                <input
                    class="input"
                    type="password"
                    bind:value={newPassword}
                    placeholder="••••••••"
                />
            </label>
            {#if passwordError}
                <aside class="alert preset-tonal-error mb-2">
                    <p class="alert-message text-xs">{passwordError}</p>
                </aside>
            {/if}
            {#if passwordOk}
                <aside class="alert preset-tonal-success mb-2">
                    <p class="alert-message text-xs">Password updated!</p>
                </aside>
            {/if}
            <button
                onclick={() =>
                    oldPassword && newPassword && $updatePassword.mutate()}
                disabled={!oldPassword || !newPassword}
                class="btn preset-filled-primary-500 text-sm disabled:opacity-50"
            >
                Change Password
            </button>
        </SettingsSection>

        <SettingsSection title="Session">
            <button
                onclick={handleLogout}
                class="btn preset-tonal-error w-full text-sm">Sign Out</button
            >
        </SettingsSection>

        <p class="text-center text-[10px] font-mono text-surface-600 mt-2">
            FocusFlow v{__APP_VERSION__}
        </p>
    </div>
</div>
