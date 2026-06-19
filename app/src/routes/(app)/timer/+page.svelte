<script lang="ts">
    import { onMount } from "svelte";
    import { wsStore } from "$lib/ws";
    import { timerStore } from "$lib/stores/timer";
    import { fmtTime } from "$lib/utils";
    import { showNotification } from "$lib/notifications";
    import { createQuery, useQueryClient } from "@tanstack/svelte-query";
    import { settings as settingsApi } from "$lib/api";
    import type { UserSettingDto } from "@/types";

    const CIRCUMFERENCE = 552.92;

    const SESSION_LABELS: Record<string, string> = {
        Work: "Focus",
        ShortBreak: "Short Break",
        LongBreak: "Long Break",
    };

    const settingsQuery = createQuery({
        queryKey: ["settings"],
        queryFn: settingsApi.getAll,
    });

    const sessionTargets = $derived.by(() => {
        const s = $settingsQuery.data ?? [];
        const get = (key: string, fallback: number) => {
            const found = s.find((x: UserSettingDto) => x.key === key);
            return found ? parseInt(found.value, 10) * 60 : fallback * 60;
        };
        return {
            Work: get("pomodoro_work_duration", 50),
            ShortBreak: get("pomodoro_short_break_duration", 10),
            LongBreak: get("pomodoro_long_break_duration", 20),
        };
    });

    const qc = useQueryClient();
    let noteInput = $state("");
    let localScore = $state<number | null>(null);
    let noteDebounce: ReturnType<typeof setTimeout> | undefined;
    let tick = $state(0);
    let tickInterval: ReturnType<typeof setInterval>;

    onMount(() => {
        wsStore.start();
        tickInterval = setInterval(() => tick++, 1000);
        return () => {
            clearInterval(tickInterval);
            wsStore.stop();
        };
    });

    let session = $derived($wsStore.state?.currentSession ?? null);
    let hasSession = $derived(!!session);
    let isWork = $derived(session?.sessionType === "Work");
    let sessionLabel = $derived(
        session
            ? (SESSION_LABELS[session.sessionType] ?? session.sessionType)
            : "Focus",
    );

    // Sync note from server when session loads (don't overwrite user edits)
    $effect(() => {
        if (session?.note && !noteInput) {
            noteInput = session.note;
        }
    });

    // Sync score from server; clear local optimistic score
    let displayScore = $derived(localScore ?? session?.concentrationScore ?? 0);

    function setScore(i: number) {
        localScore = i;
        wsStore.send({ type: "updateScore", score: i });
    }

    function autoResize(el: HTMLTextAreaElement) {
        el.style.height = "auto";
        el.style.height = el.scrollHeight + "px";
    }

    function onNoteInput(e: Event) {
        autoResize(e.currentTarget as HTMLTextAreaElement);
        clearTimeout(noteDebounce);
        noteDebounce = setTimeout(() => {
            wsStore.send({ type: "updateNote", note: noteInput });
        }, 800);
    }

    let remaining = $derived.by(() => {
        void tick;
        if (!session) return sessionTargets.Work;
        const now = Math.floor(Date.now() / 1000);
        const elapsed = now - session.sessionStartTime;
        const target = sessionTargets[session.sessionType] ?? sessionTargets.Work;
        return target - elapsed;
    });

    let isOvertime = $derived(hasSession && remaining < 0);
    let displayRemaining = $derived(isOvertime ? Math.abs(remaining) : Math.max(0, remaining));
    let clampedProgress = $derived(isOvertime ? 1 : Math.max(0, Math.min(1, 1 - remaining / (sessionTargets[session?.sessionType ?? "Work"] ?? sessionTargets.Work))));

    let prevRemaining = $state(0);
    $effect(() => {
        if (prevRemaining > 0 && remaining <= 0 && hasSession) {
            const msg = session!.sessionType === "Work"
                ? { title: "FocusFlow", body: "Focus session complete!" }
                : { title: "FocusFlow", body: "Break's over! Time to focus." };
            showNotification(msg.title, msg.body).catch(() => {});
        }
        prevRemaining = remaining;
    });

    let dashOffset = $derived(CIRCUMFERENCE * (1 - clampedProgress));
</script>

<div class="flex-1 min-h-0 flex flex-col overflow-hidden">
    <div
        class="flex-1 overflow-y-auto pb-24 flex flex-col items-center px-4 pt-4 gap-4"
    >
        <div class="w-full flex items-center justify-between">
            {#if $timerStore.selectedTask}
                <div
                    class="flex items-center gap-2 bg-primary-500/10 border border-primary-500/30 rounded-full px-3 py-1.5 max-w-[75%]"
                >
                    <div
                        class="size-1.5 rounded-full bg-primary-400 shrink-0"
                    ></div>
                    <span class="text-xs text-primary-300 truncate"
                        >{$timerStore.selectedTask.title}</span
                    >
                </div>
            {:else}
                <div
                    class="flex items-center gap-2 bg-surface-800 border border-surface-700 rounded-full px-3 py-1.5"
                >
                    <span class="text-xs text-surface-500"
                        >No task selected</span
                    >
                </div>
            {/if}
            <div
                class={`size-2 rounded-full ${$wsStore.connected ? "bg-green-400" : "bg-surface-600"}`}
                title={$wsStore.connected ? "Connected" : "Disconnected"}
            ></div>
        </div>

        <p class="text-xs font-mono text-surface-500 uppercase tracking-widest">
            {sessionLabel}
        </p>
        {#if hasSession}
            <p class="text-[10px] font-mono text-surface-600">
                {#if isWork}
                    Work {$wsStore.state!.completedWorkSessions} of {$wsStore.state!.longBreakInterval}
                {:else if session!.sessionType === "ShortBreak"}
                    Short break {$wsStore.state!.completedWorkSessions}
                {:else}
                    Long break
                {/if}
            </p>
        {/if}

        <div class="relative">
            <svg viewBox="0 0 200 200" width="220" height="220">
                <circle
                    cx="100"
                    cy="100"
                    r="88"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="6"
                    class="text-surface-800"
                />
                <circle
                    cx="100"
                    cy="100"
                    r="88"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="6"
                    stroke-linecap="round"
                    class={isOvertime ? "text-red-500" : isWork ? "text-primary-500" : "text-green-500"}
                    stroke-dasharray={CIRCUMFERENCE}
                    stroke-dashoffset={dashOffset}
                    transform="rotate(-90 100 100)"
                    style="transition: stroke-dashoffset 0.5s ease"
                />
            </svg>
            <div
                class="absolute inset-0 flex flex-col items-center justify-center"
            >
                <span
                    class="text-4xl font-mono font-bold tabular-nums {isOvertime ? 'text-red-400' : 'text-surface-50'}"
                    >{fmtTime(displayRemaining)}</span
                >
                <span class="text-xs mt-1 {isOvertime ? 'text-red-400/70' : 'text-surface-500'}"
                    >{isOvertime ? "Over" : hasSession ? "Remaining" : "Ready"}</span
                >
            </div>
        </div>

        <div class="flex items-center gap-3">
            {#if !isWork}
                <button
                    class="btn preset-filled-primary-500 px-6"
                    onclick={() => wsStore.send({ type: "start" })}
                >
                    {hasSession ? "Resume" : "Start"}
                </button>
            {/if}
            {#if isWork}
                <button
                    class="btn preset-tonal-surface px-6"
                    onclick={() => wsStore.send({ type: "break" })}
                    >Break</button
                >
            {/if}
            {#if hasSession}
                <button
                    class="btn preset-tonal-error px-6"
                    onclick={() => {
                        wsStore.send({ type: "terminate" });
                        localScore = null;
                        noteInput = "";
                        qc.invalidateQueries({ queryKey: ["stats"] });
                    }}>Stop</button
                >
            {/if}
        </div>

        {#if hasSession && isWork}
            <div
                class="w-full card bg-surface-900 border border-surface-700 p-4 flex flex-col gap-4"
            >
                <div>
                    <p
                        class="text-xs font-mono text-surface-500 uppercase tracking-widest mb-2"
                    >
                        Focus Score
                    </p>
                    <div class="flex gap-3">
                        {#each [1, 2, 3, 4, 5] as i (i)}
                            <button
                                onclick={() => setScore(i)}
                                class={`text-2xl transition-colors leading-none ${displayScore >= i ? "text-primary-400" : "text-surface-500 hover:text-surface-400"}`}
                                aria-label={`Score ${i}`}>★</button
                            >
                        {/each}
                    </div>
                </div>

                <div>
                    <p
                        class="text-xs font-mono text-surface-500 uppercase tracking-widest mb-2"
                    >
                        Note
                    </p>
                    <textarea
                        class="textarea w-full text-sm bg-surface-800 border-surface-700 text-surface-100 placeholder:text-surface-500 overflow-hidden"
                        placeholder="Add a note…"
                        style="min-height: 120px; resize: none; field-sizing: content;"
                        bind:value={noteInput}
                        oninput={onNoteInput}
                    ></textarea>
                </div>
            </div>
        {/if}

        {#if $wsStore.error}
            <aside class="alert preset-tonal-error w-full">
                <p class="alert-message text-sm">
                    Connection error: {$wsStore.error}
                </p>
            </aside>
        {/if}
    </div>
</div>
