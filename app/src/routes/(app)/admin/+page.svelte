<script lang="ts">
    import { goto } from "$app/navigation";
    import { onMount } from "svelte";
    import { admin, type UserListItem, type UserStats } from "$lib/api/admin";
    import { users } from "$lib/api";

    let userList = $state<UserListItem[]>([]);
    let loading = $state(true);
    let adminCheckDone = $state(false);

    let passwordDialogId = $state<string | null>(null);
    let newPassword = $state("");
    let passwordError = $state("");

    let createDialogOpen = $state(false);
    let createUsername = $state("");
    let createPassword = $state("");
    let createError = $state("");

    let editingUsername = $state<string | null>(null);
    let editValue = $state("");

    let statsLoadId = $state<string | null>(null);
    let statsCache = $state<Map<string, UserStats>>(new Map());
    let statsLoading = $state(false);

    async function checkAdmin() {
        try {
            const me = await users.me();
            if (me?.role !== "Admin") {
                goto("/");
                return;
            }
            adminCheckDone = true;
        } catch {
            goto("/login");
        }
    }

    async function loadUsers() {
        loading = true;
        try {
            userList = await admin.listUsers();
        } catch (e) {
            console.error("Failed to load users", e);
        } finally {
            loading = false;
        }
    }

    async function handleDelete(id: string, username: string) {
        if (!confirm(`Delete user "${username}"?`)) return;
        try {
            await admin.deleteUser(id);
            userList = userList.filter((u) => u.id !== id);
        } catch (e) {
            console.error("Failed to delete user", e);
        }
    }

    function openPasswordDialog(id: string) {
        passwordDialogId = id;
        newPassword = "";
        passwordError = "";
    }

    async function handleChangePassword() {
        if (!passwordDialogId || !newPassword) return;
        try {
            await admin.changePassword(passwordDialogId, newPassword);
            passwordDialogId = null;
        } catch (e: any) {
            const msg = e?.response?.data?.error?.code === "BAD_REQUEST"
                ? "Password must be at least 8 characters with uppercase, lowercase, and digit"
                : "Failed to change password";
            passwordError = msg;
        }
    }

    function openCreateDialog() {
        createUsername = "";
        createPassword = "";
        createError = "";
        createDialogOpen = true;
    }

    async function handleCreate() {
        if (!createUsername || !createPassword) return;
        try {
            await users.create({ username: createUsername, password: createPassword });
            createDialogOpen = false;
            await loadUsers();
        } catch (e: any) {
            createError = e?.response?.data?.error?.message || "Failed to create user";
        }
    }

    function startEditUsername(id: string, current: string) {
        editingUsername = id;
        editValue = current;
    }

    async function saveEditUsername(id: string) {
        if (!editValue.trim()) {
            editingUsername = null;
            return;
        }
        try {
            await admin.updateUser(id, { username: editValue.trim() });
            const u = userList.find((u) => u.id === id);
            if (u) u.username = editValue.trim();
            editingUsername = null;
        } catch (e: any) {
            console.error("Failed to update username", e);
            editingUsername = null;
        }
    }

    async function toggleRole(id: string, currentRole: string) {
        const newRole = currentRole === "Admin" ? "User" : "Admin";
        try {
            await admin.updateUser(id, { role: newRole });
            const u = userList.find((u) => u.id === id);
            if (u) u.role = newRole;
        } catch (e: any) {
            console.error("Failed to update role", e);
        }
    }

    async function loadStats(id: string) {
        if (statsCache.has(id)) {
            statsLoadId = statsLoadId === id ? null : id;
            return;
        }
        statsLoading = true;
        try {
            const s = await admin.getUserStats(id);
            statsCache.set(id, s);
            statsLoadId = id;
        } catch (e) {
            console.error("Failed to load stats", e);
        } finally {
            statsLoading = false;
        }
    }

    function fmtDuration(secs: number): string {
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    onMount(async () => {
        await checkAdmin();
        if (adminCheckDone) await loadUsers();
    });
</script>

{#if !adminCheckDone}
    <div class="flex-1 flex items-center justify-center">
        <p class="text-surface-500">Checking access...</p>
    </div>
{:else}
    <div class="flex-1 overflow-y-auto px-4 pb-6">
        <div class="max-w-2xl mx-auto">
            <div class="flex items-center justify-between mb-4 pt-2">
                <h2 class="text-lg font-semibold text-surface-100">User Management</h2>
                <div class="flex items-center gap-2">
                    <button
                        onclick={openCreateDialog}
                        class="btn preset-filled-primary-500 text-xs h-7 px-3"
                    >+ New User</button>
                    <span class="text-xs font-mono text-surface-500">{userList.length} users</span>
                </div>
            </div>

            {#if loading}
                <p class="text-surface-500 text-sm">Loading users...</p>
            {:else}
                <div class="flex flex-col gap-2">
                    {#each userList as user (user.id)}
                        <div class="bg-surface-900 border border-surface-800 rounded-lg overflow-hidden">
                            <div class="p-3 flex items-center gap-3">
                                <div class="size-9 bg-surface-800 rounded-full grid place-items-center font-semibold text-sm text-surface-200 shrink-0">
                                    {user.username.charAt(0).toUpperCase()}
                                </div>
                                <div class="flex-1 min-w-0">
                                    {#if editingUsername === user.id}
                                        <div class="flex items-center gap-1">
                                            <input
                                                type="text"
                                                bind:value={editValue}
                                                class="w-full bg-surface-800 border border-surface-700 rounded px-2 py-0.5 text-sm text-surface-100 outline-none focus:border-primary-500"
                                                onkeydown={(e) => {
                                                    if (e.key === "Enter") saveEditUsername(user.id);
                                                    if (e.key === "Escape") editingUsername = null;
                                                }}
                                                onblur={() => saveEditUsername(user.id)}
                                                autofocus
                                            />
                                        </div>
                                    {:else}
                                        <button
                                            onclick={() => startEditUsername(user.id, user.username)}
                                            class="text-sm font-medium text-surface-100 truncate hover:text-primary-400 transition-colors text-left"
                                        >{user.username}</button>
                                    {/if}
                                    <div class="flex items-center gap-2 mt-0.5">
                                        <button
                                            onclick={() => toggleRole(user.id, user.role)}
                                            class="text-[10px] font-mono uppercase tracking-wider px-1.5 py-0.5 rounded border transition-colors hover:opacity-80 {user.role === 'Admin' ? 'text-yellow-400 border-yellow-400/40' : 'text-surface-500 border-surface-600'}"
                                        >{user.role}</button>
                                        <button
                                            onclick={() => loadStats(user.id)}
                                            class="text-[10px] text-surface-500 hover:text-surface-300 transition-colors"
                                        >{statsLoadId === user.id ? 'Hide stats' : 'Stats'}</button>
                                    </div>
                                </div>
                                <div class="flex gap-1.5 shrink-0">
                                    <button
                                        onclick={() => openPasswordDialog(user.id)}
                                        class="btn preset-tonal-surface text-xs h-7 px-2.5 text-surface-400"
                                    >Password</button>
                                    <button
                                        onclick={() => handleDelete(user.id, user.username)}
                                        class="btn preset-tonal-surface text-xs h-7 px-2.5 text-red-400 hover:text-red-300"
                                    >Delete</button>
                                </div>
                            </div>
                            {#if statsLoadId === user.id}
                                <div class="border-t border-surface-800 px-3 py-2 flex gap-4 text-xs">
                                    {#if statsCache.has(user.id)}
                                        {@const s = statsCache.get(user.id)!}
                                        <span class="text-surface-400">Sessions: <strong class="text-surface-200">{s.totalSessions}</strong></span>
                                        <span class="text-surface-400">Focus time: <strong class="text-surface-200">{fmtDuration(s.totalFocusDuration)}</strong></span>
                                    {:else if statsLoading}
                                        <span class="text-surface-500">Loading stats…</span>
                                    {/if}
                                </div>
                            {/if}
                        </div>
                    {/each}
                </div>
            {/if}
        </div>
    </div>
{/if}

{#if passwordDialogId}
    <div
        class="absolute inset-0 bg-black/55 backdrop-blur-sm z-30 flex items-center justify-center p-4"
        onclick={() => (passwordDialogId = null)}
        role="presentation"
    >
        <div
            class="bg-surface-900 border border-surface-700 rounded-xl p-5 w-full max-w-sm"
            onclick={(e) => e.stopPropagation()}
            role="dialog"
        >
            <h3 class="text-base font-semibold text-surface-100 mb-4">Change Password</h3>
            <input
                type="password"
                bind:value={newPassword}
                placeholder="New password"
                class="w-full bg-surface-800 border border-surface-700 rounded-lg px-3 py-2 text-sm text-surface-100 placeholder:text-surface-500 outline-none focus:border-primary-500 mb-1"
            />
            {#if passwordError}
                <p class="text-xs text-red-400 mb-3">{passwordError}</p>
            {/if}
            <div class="flex gap-2 justify-end mt-4">
                <button
                    onclick={() => (passwordDialogId = null)}
                    class="btn preset-tonal-surface text-sm h-8 px-3 text-surface-400"
                >Cancel</button>
                <button
                    onclick={handleChangePassword}
                    class="btn preset-filled-primary-500 text-sm h-8 px-3"
                >Save</button>
            </div>
        </div>
    </div>
{/if}

{#if createDialogOpen}
    <div
        class="absolute inset-0 bg-black/55 backdrop-blur-sm z-30 flex items-center justify-center p-4"
        onclick={() => (createDialogOpen = false)}
        role="presentation"
    >
        <div
            class="bg-surface-900 border border-surface-700 rounded-xl p-5 w-full max-w-sm"
            onclick={(e) => e.stopPropagation()}
            role="dialog"
        >
            <h3 class="text-base font-semibold text-surface-100 mb-4">Create User</h3>
            <div class="flex flex-col gap-3">
                <input
                    type="text"
                    bind:value={createUsername}
                    placeholder="Username"
                    class="w-full bg-surface-800 border border-surface-700 rounded-lg px-3 py-2 text-sm text-surface-100 placeholder:text-surface-500 outline-none focus:border-primary-500"
                />
                <input
                    type="password"
                    bind:value={createPassword}
                    placeholder="Password (8+ chars, upper+lower+digit)"
                    class="w-full bg-surface-800 border border-surface-700 rounded-lg px-3 py-2 text-sm text-surface-100 placeholder:text-surface-500 outline-none focus:border-primary-500"
                />
                {#if createError}
                    <p class="text-xs text-red-400">{createError}</p>
                {/if}
            </div>
            <div class="flex gap-2 justify-end mt-4">
                <button
                    onclick={() => (createDialogOpen = false)}
                    class="btn preset-tonal-surface text-sm h-8 px-3 text-surface-400"
                >Cancel</button>
                <button
                    onclick={handleCreate}
                    class="btn preset-filled-primary-500 text-sm h-8 px-3"
                >Create</button>
            </div>
        </div>
    </div>
{/if}
