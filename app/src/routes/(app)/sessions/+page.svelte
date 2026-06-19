<script lang="ts">
    import { createQuery, createMutation, useQueryClient } from "@tanstack/svelte-query";
    import { sessionsApi } from "$lib/api";

    const queryClient = useQueryClient();
    import type { FocusSessionDto, SessionTypeEnum } from "@/types";

    const sessionsQuery = createQuery({
        queryKey: ["sessions"],
        queryFn: () => sessionsApi.list(),
    });

    let editingId = $state<string | null>(null);

    let editTaskId = $state("");
    let editSessionType = $state<SessionTypeEnum>("Work");
    let editScore = $state<number>(0);
    let editNotes = $state("");
    let editDuration = $state<number>(0);

    function startEdit(s: FocusSessionDto) {
        editingId = s.id;
        editTaskId = s.taskId ?? "";
        editSessionType = s.sessionType;
        editScore = s.concentrationScore ?? 0;
        editNotes = s.notes ?? "";
        editDuration = s.actualDuration ?? 0;
    }

    function cancelEdit() {
        editingId = null;
    }

    const updateMutation = createMutation({
        mutationFn: (s: FocusSessionDto) =>
            sessionsApi.update(s.id, {
                taskId: editTaskId || null,
                sessionType: editSessionType,
                actualDuration: editDuration || null,
                concentrationScore: editScore || null,
                notes: editNotes || null,
            }),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["sessions"] });
            editingId = null;
        },
    });

    const deleteMutation = createMutation({
        mutationFn: (id: string) => sessionsApi.delete(id),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ["sessions"] });
        },
    });

    const SESSION_LABELS: Record<SessionTypeEnum, string> = {
        Work: "Work",
        ShortBreak: "Short Break",
        LongBreak: "Long Break",
    };

    function fmtDuration(secs: number | null): string {
        if (!secs) return "—";
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return `${m}:${String(s).padStart(2, "0")}`;
    }

    function fmtDate(ts: number): string {
        return new Date(ts * 1000).toLocaleDateString(undefined, {
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
        });
    }
</script>

<div class="flex-1 min-h-0 flex flex-col overflow-hidden px-4 pt-3">
    <h1 class="text-lg font-bold text-surface-50 mb-3">Sessions</h1>

    {#if $sessionsQuery.isPending}
        <div class="flex-1 flex items-center justify-center text-surface-500 text-sm font-mono">
            Loading…
        </div>
    {:else if $sessionsQuery.data}
        {@const sessions = $sessionsQuery.data.focusSessions}
        <div class="flex-1 overflow-y-auto pb-24 flex flex-col gap-2">
            {#if sessions.length === 0}
                <div class="flex-1 flex items-center justify-center text-surface-500 text-sm font-mono">
                    No sessions yet
                </div>
            {:else}
                {#each sessions as s (s.id)}
                    <div class="card bg-surface-900 border border-surface-700 p-3">
                        {#if editingId === s.id}
                            <div class="flex flex-col gap-2">
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-mono text-surface-500 uppercase tracking-widest">Edit session</span>
                                    <button class="btn btn-icon preset-tonal-surface size-7" onclick={cancelEdit}>
                                        <svg viewBox="0 0 16 16" width="12" height="12" stroke="currentColor" fill="none" stroke-width="1.6">
                                            <line x1="4" y1="4" x2="12" y2="12"/>
                                            <line x1="12" y1="4" x2="4" y2="12"/>
                                        </svg>
                                    </button>
                                </div>
                                <div class="grid grid-cols-2 gap-2">
                                    <label class="flex flex-col gap-0.5">
                                        <span class="text-[10px] text-surface-500 font-mono">Type</span>
                                        <select bind:value={editSessionType} class="select preset-filled-surface text-xs w-full">
                                            <option value="Work">Work</option>
                                            <option value="ShortBreak">Short Break</option>
                                            <option value="LongBreak">Long Break</option>
                                        </select>
                                    </label>
                                    <label class="flex flex-col gap-0.5">
                                        <span class="text-[10px] text-surface-500 font-mono">Duration (min)</span>
                                        <input type="number" bind:value={editDuration} class="input preset-filled-surface text-xs w-full" min="0" step="60"/>
                                    </label>
                                </div>
                                <div class="grid grid-cols-2 gap-2">
                                    <label class="flex flex-col gap-0.5">
                                        <span class="text-[10px] text-surface-500 font-mono">Score</span>
                                        <select bind:value={editScore} class="select preset-filled-surface text-xs w-full">
                                            {#each [0, 1, 2, 3, 4, 5] as v}
                                                <option value={v}>{v}</option>
                                            {/each}
                                        </select>
                                    </label>
                                    <label class="flex flex-col gap-0.5">
                                        <span class="text-[10px] text-surface-500 font-mono">Task ID</span>
                                        <input type="text" bind:value={editTaskId} class="input preset-filled-surface text-xs w-full" placeholder="uuid"/>
                                    </label>
                                </div>
                                <label class="flex flex-col gap-0.5">
                                    <span class="text-[10px] text-surface-500 font-mono">Notes</span>
                                    <textarea bind:value={editNotes} class="input preset-filled-surface text-xs w-full" rows="2"></textarea>
                                </label>
                                <div class="flex gap-2 justify-end">
                                    <button class="btn preset-tonal-surface text-xs" onclick={cancelEdit}>Cancel</button>
                                    <button class="btn preset-tonal-primary text-xs" onclick={() => $updateMutation.mutate(s)} disabled={$updateMutation.isPending}>Save</button>
                                </div>
                            </div>
                        {:else}
                            <div class="flex items-start justify-between gap-2">
                                <div class="flex-1 min-w-0">
                                    <div class="flex items-center gap-2 mb-0.5">
                                        <span class="text-xs font-semibold text-surface-100">
                                            {SESSION_LABELS[s.sessionType]}
                                        </span>
                                        {#if s.concentrationScore != null}
                                            <span class="text-[10px] text-yellow-400">{'★'.repeat(s.concentrationScore)}{'☆'.repeat(5 - s.concentrationScore)}</span>
                                        {/if}
                                    </div>
                                    <div class="flex items-center gap-2 text-[11px] text-surface-500">
                                        <span>{fmtDuration(s.actualDuration)}</span>
                                        <span>·</span>
                                        <span>{fmtDate(s.startedAt)}</span>
                                    </div>
                                    {#if s.notes}
                                        <p class="text-xs text-surface-400 mt-1 truncate">{s.notes}</p>
                                    {/if}
                                </div>
                                <div class="flex gap-1 shrink-0">
                                    <button class="btn btn-icon preset-tonal-surface size-7" onclick={() => startEdit(s)}>
                                        <svg viewBox="0 0 16 16" width="12" height="12" stroke="currentColor" fill="none" stroke-width="1.5">
                                            <path d="M11 2l3 3-9 9H2v-3z"/>
                                        </svg>
                                    </button>
                                    <button class="btn btn-icon preset-tonal-surface hover:preset-tonal-error size-7" onclick={() => $deleteMutation.mutate(s.id)} disabled={$deleteMutation.isPending}>
                                        <svg viewBox="0 0 16 16" width="12" height="12" stroke="currentColor" fill="none" stroke-width="1.5">
                                            <path d="M2 4h12M5 4V2.5A.5.5 0 0 1 5.5 2h5a.5.5 0 0 1 .5.5V4M12 4v9.5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4"/>
                                        </svg>
                                    </button>
                                </div>
                            </div>
                        {/if}
                    </div>
                {/each}
            {/if}
        </div>
    {/if}
</div>
