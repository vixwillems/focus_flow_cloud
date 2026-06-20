# AGENTS.md — FocusFlow Cloud

A guide for AI coding agents (and humans) working in this monorepo. Read this before making changes — it captures the layout, the conventions that differ from a "default" project, and the commands the project's `just` recipes expect.

## Overview

Three independent projects in one repo, coordinated by `just`:

| Project | Stack | Package manager | Entrypoint |
| --- | --- | --- | --- |
| `backend/` | Rust (Axum 0.8 + Diesel 2 + Postgres) | Cargo workspace | `backend/src/main.rs` |
| `app/` | SvelteKit SPA + Tauri v2 (desktop + iOS) | Bun | SvelteKit routes; `app/src-tauri/` for the native shell |
| `doc/` | Docusaurus v3 | Bun | `doc/` |

Clean architecture on the backend: `domain/` ← `application/` ← `adapters/` ← `infrastructure/` (all under `backend/crates/`).

## Backend layout (Rust)

```
backend/
├── Cargo.toml                  # workspace manifest
├── Diesel.toml
├── Dockerfile                  # multi-stage build with cargo-chef
├── .env.example                # every required env var
├── migrations/                 # Diesel migrations (auto-embedded at build time)
├── src/main.rs                 # binary entry point
├── tests/                      # integration / e2e tests (testcontainers)
└── crates/
    ├── domain/                 # entities + domain traits (no I/O, no async)
    ├── application/            # use cases (one file per use case)
    │   └── {bounded_context}/
    │       ├── entities/       # use-case-shaped structs
    │       ├── traits/         # repository / port traits
    │       └── use_cases/      # one struct per use case, registered in `mod.rs`
    ├── adapters/               # HTTP handlers + Diesel repos
    │   └── {bounded_context}/
    │       ├── http/           # one file per route handler
    │       └── persistence/    # db_models + Diesel impls of repository traits
    └── infrastructure/         # config.rs, setup/, AppState wiring
```

**Bounded contexts** currently in the codebase: `user` (auth + admin), `tasks` (categories / focus sessions / pomodoro), `flashcards` (decks + reviews + stats), `shared` (push subscriptions, reminders, version, errors, middleware).

### Adding a new use case (the canonical pattern)

1. `application/.../traits/{name}_repository.rs` — define the port trait if needed.
2. `application/.../use_cases/{name}/` — one file per use case, each struct with `pub struct X { pub repo: Arc<...> }` + `async fn execute(...)` or `pub async fn run(...)`.
3. Register the struct in `application/.../use_cases/{context}/mod.rs`.
4. Implement repo methods in `adapters/.../persistence/impls/{name}_persistence_impl.rs`.
5. HTTP handler in `adapters/.../http/{resource}/{action}.rs`, exported through `routes.rs`.
6. Wire the use case into `AppState` (`infrastructure/src/setup/{context}_setup.rs`).
7. Add the env var (if any) to `backend/.env.example`.

### Backend env vars (read by `infrastructure::config::load_from_env`)

| Var | Required | Notes |
| --- | --- | --- |
| `SERVER_PORT` | yes | integer |
| `CORS_ORIGIN` | yes | `*` for dev, origin URL for prod |
| `DATABASE_BASE_URL` | yes | `host:port` (no protocol) |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | yes | |
| `JWT_SECRET` | yes | |
| `VAPID_PRIVATE_KEY` | yes | Web Push signing; placeholder works but push will fail |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | no | Seed admin at startup if set |
| `OTLP_ENDPOINT` | no | OpenTelemetry collector, e.g. `http://localhost:4317` |
| `APP_ENV` | no | informational, e.g. `production` |

A reference `backend/.env.example` ships in the repo. `dotenvy::dotenv().ok()` is called at startup so the file is loaded automatically.

## App layout (SvelteKit + Tauri)

```
app/
├── src/
│   ├── app.css                 # Skeleton + Tailwind v4 + theme imports
│   ├── +layout.svelte          # global shell: SideDrawer, BottomNav, drawer state
│   ├── components/             # reusable Svelte 5 (runes) components
│   │   ├── BottomNav.svelte
│   │   ├── SideDrawer.svelte
│   │   ├── DateInput.svelte
│   │   ├── DateTimeInput.svelte
│   │   ├── TimeInput.svelte
│   │   ├── categories/
│   │   ├── settings/
│   │   └── tasks/
│   ├── lib/
│   │   ├── api/                # one TypeScript module per resource (axios)
│   │   │   ├── client.ts       # base axios instance (reads ff_server_url from localStorage)
│   │   │   ├── auth.ts tasks.ts sessions.ts flashcards.ts categories.ts
│   │   │   ├── admin.ts users.ts settings.ts stats.ts
│   │   │   ├── reminders.ts push.ts
│   │   │   └── index.ts        # barrel re-exports
│   │   ├── ws.ts               # WebSocket client → typed UpdatePomodoroStateMessage
│   │   └── ...                 # utils
│   ├── routes/                 # SvelteKit file-based routes
│   │   ├── +layout.ts          # `ssr = false`, `prerender = false`
│   │   ├── setup/              # first-launch: pick server URL
│   │   ├── login/              # auth screen
│   │   └── (app)/              # authenticated routes
│   │       ├── +page.svelte                # tasks (the home)
│   │       ├── timer/  cards/  sessions/  categories/
│   │       ├── calendar/  stats/  settings/  admin/
│   └── types/                  # hand-written + `generated/` from ts-rs
└── src-tauri/                  # Tauri v2 native shell (Rust + Swift bridging)
    ├── tauri.conf.json
    ├── Cargo.toml              # `focus-flow` 1.1.0, depends on tauri 2.11.x
├── gen/apple/              # generated Xcode project (DO NOT edit by hand)
│   ├── focus-flow.xcodeproj
│   ├── project.yml          # xcodegen source of truth (track via git add -f)
│   └── Sources/             # iOS Swift/Obj-C++ sources, including the
│                            # FocusFlowWidgets extension target
    ├── icons/
    └── Info.plist
```

### App conventions

- **SPA-only**: `src/routes/+layout.ts` has `ssr = false`, `prerender = false`. `adapter-static` with `fallback: 'index.html'`. There's no Node server in production.
- **Svelte 5 runes**: components use `$state`, `$derived`, `$effect`. No legacy `let` reactivity.
- **No JS linting/formatting**: only TypeScript strict mode (`tsconfig.json`). No ESLint, Prettier, or Biome.
- **No frontend tests**: no test framework configured.
- **Server URL is runtime config**: read from `localStorage.ff_server_url` on the client; the login page lets the user enter it. The setup route (`/setup`) handles the first-launch flow.
- **Tauri target versions** (kept in sync with the iOS guide):
  - `tauri = "2.11.x"`
  - `tauri-build = "2.6.x"`
  - `app_lib` is the lib name; the binary is `focus-flow`.
  - iOS deployment target: 14.0
  - Bundle identifier: `com.francescopio.focusflow`

### Type generation

`bun run generate:types` runs `cargo test -p adapters --features ts` with `TS_RS_EXPORT_DIR=../../app/src/types/generated`. Use it any time a `#[derive(TS)]` struct changes.

## Cross-cutting conventions

- **Versioning**: both `backend/Cargo.toml` and `app/package.json` are bumped in lockstep by the `bump_version.yaml` CI workflow when a commit message contains `[patch]`, `[minor]`, or `[major]`. Use `just bump-patch` / `bump-minor` / `bump-major` locally; `just bump-auto` detects the bump from commit messages since the last tag.
- **Conventional Commits**: required for the bump workflow. `feat:` → minor, `fix:` → patch, `feat!:` or `BREAKING CHANGE:` → major. `chore:` / `docs:` / `refactor:` / `test:` do not bump.
- **CHANGELOG.md** is generated by `git-cliff` (see `cliff.toml`) during the bump.
- **CI skips `chore: bump` commits** to prevent infinite loops from the auto-bump.
- **iOS guide**: see `app/ios-fix.md` for the full Xcode 27 beta + iOS 27 device build dance. TL;DR: build with `xcode-select` pointing to Xcode 26; SDK stubs in `/Applications/Xcode-beta.app/.../MacOSX27.0.sdk/` are only needed if you fall back to Xcode 27.

## Essential commands

All commands are run from the repo root unless stated otherwise. `just` is the primary task runner; `just --list` shows the full set.

### `just` recipes

| Recipe | What it does |
| --- | --- |
| `just install` | `cargo fetch` + `bun install` for the whole repo |
| `just backend-build` | `cd backend && cargo build` (debug) |
| `just backend-build-release` | `cd backend && cargo build --release` |
| `just backend-run` | `cd backend && cargo run --bin focus_flow_cloud` |
| `just backend-run-debug` | same, with `RUST_LOG=debug` |
| `just backend-test` | `cargo test --workspace --lib --bins` (unit + integration, no e2e) |
| `just backend-test-e2e` | needs Docker (testcontainers spins up Postgres) |
| `just backend-fmt-check` | `cargo fmt --all -- --check` |
| `just backend-lint` | `cargo clippy --workspace -- -D warnings` |
| `just backend-cov` | coverage via `cargo llvm-cov` (slow) |
| `just backend-check` | fmt → clippy → tests |
| `just app-install` | `cd app && bun install` |
| `just app-dev` | `cd app && bun run tauri:dev` |
| `just app-build` | `cd app && bun run tauri:build` |
| `just app-check` | `cd app && bun run check` (type-check only) |
| `just app-generate-type` | regenerate TS types from Rust DTOs |
| `just doc-serve` / `doc-build` | Docusaurus dev/build |
| `just docker-build-backend` | `docker buildx build --platform linux/amd64 -f backend/Dockerfile -t focusflow-backend:latest --load .` (from repo root) |
| `just test-all` | backend tests + app type-check |
| `just check-all` | full CI: backend fmt+clippy+coverage+build + app check+build |
| `just bump-patch` / `bump-minor` / `bump-major` / `bump-auto` | bump both versions, regenerate CHANGELOG, tag |

### Single-package commands (run from `backend/`)

```sh
cargo test -p <crate>                    # one crate
cargo test -p adapters --features ts     # regenerate TS types
cargo clippy --workspace -- -D warnings
cargo fmt --all -- --check
```

### App scripts (run from `app/`)

```sh
bun run dev                # vite dev on :5173 (no Tauri)
bun run build              # static build to ./build
bun run check              # svelte-kit sync + svelte-check
bun run generate:types     # regenerate TS types from Rust
bun run tauri:dev          # Tauri desktop dev with hot-reload
bun run tauri:build        # Tauri desktop production build
bun run tauri ios init     # one-time: generate Xcode project
bun run tauri ios build --debug --target aarch64   # iOS device build
```

### Deployment

- **Docker**: `docker-compose.yml` at the repo root runs `postgres:16-bookworm` + the backend image built from `backend/Dockerfile`. Bring it up with `docker compose up -d`; the backend waits for the DB via healthcheck. Build context is the repo root (not `backend/`), tag is `focusflow-backend:latest`. Deploy to the `focuscloud` Debian LXC server via `docker save` → `scp` → `docker load` → `docker compose up -d --force-recreate --no-deps backend` over `ssh agent@focuscloud` (the server user needs `sudo` for docker; pass the password via `echo "developP4s$" | sudo -S`).
- **k8s**: see `k8s/` for manifests. Apply `namespace.yaml` first, then the rest in dependency order.
- **iOS**: see `app/ios-fix.md` for the full step-by-step (Xcode 26 toolchain + iOS 27 device + free Apple ID). The iOS build flow now includes a FocusFlowWidgets extension target for Live Activities and StandBy widgets; the Swift sources for the extension are force-added to git because they live under the gitignored `gen/apple/Sources/` tree.

## Health check

`wget --spider http://localhost:8080/api-docs/openapi.json` (or any container) — the server exposes its OpenAPI doc at `/api-docs/openapi.json` and a Swagger UI at `/api-docs`.

## OpenAPI

Auto-generated from `utoipa` annotations in the adapters crate. `adapters/src/openapi.rs` is the entry point; the `routes()` and individual handler structs all carry the `#[utoipa::path(...)]` attribute. If you add a new route, document it there or it won't appear in the API docs.

## Testing

- **Backend unit tests** live next to the code (`#[cfg(test)] mod tests`), or in `application/.../use_cases/{name}/{name}_test.rs` for use cases.
- **Backend e2e tests** live in `backend/tests/` and use `testcontainers` to spin up Postgres. Need Docker at runtime.
- **No frontend tests** by design.

## Stale docs to be aware of

- `app/README.md` is stale — it still describes a React/Vite stack. The real stack is SvelteKit + Tauri (see above).

## Hard-won knowledge (read this before debugging Tauri iOS)

This section captures things that cost real time to figure out. The next agent who needs to touch the iOS build pipeline should skim it first.

### Tauri iOS build pipeline (the actual mechanics)

`bun run tauri ios build` is a thin wrapper. The real work happens in this chain:

1. `bun run build` — Vite builds the SvelteKit SPA into `app/build/`.
2. The Tauri CLI **starts a JSON-RPC WebSocket server on `127.0.0.1:<random-port>`** and writes the address to:
   ```
   $TMPDIR/com.francescopio.focusflow-server-addr
   ```
   On macOS, `$TMPDIR` is `/var/folders/.../T/<userid>/`, **NOT `/tmp/`**. If you grep `/tmp` you will not find the file.
3. `xcodebuild` runs the pre-build script defined in `app/src-tauri/gen/apple/project.yml`:
   ```
   bun tauri ios xcode-script -v --platform ${PLATFORM_DISPLAY_NAME:?} ...
   ```
4. `tauri ios xcode-script` reads the addr file, connects to the WebSocket, asks for the original `CliOptions` via JSON-RPC method `"options"`, and only THEN runs `cargo build --target aarch64-apple-ios --features tauri/custom-protocol --lib`. Without the WebSocket server, **the script panics at startup** with `failed to build WebSocket client: Connection refused`.

**Consequence:** if you want to call `xcodebuild` directly (for example, to target a specific device), you must provide a stand-in JSON-RPC server. See "Multi-device iOS builds" below.

### Multi-device iOS builds (free Apple ID)

The provisioning profile generated for a free Apple ID is pinned to whatever device was active during the first `xcodebuild` invocation. To install on additional devices (e.g. the iPad Pro M4 after you've already built for the iPhone), you need to:

1. **Bypass the Tauri CLI** (which auto-targets the first available iPhone and won't re-sign for a second device) and call `xcodebuild` directly with the target device as the destination.
2. **Provide a fake Tauri WebSocket server** so the pre-build script doesn't panic. A working shim is at `/tmp/focusflow/tauri_ws.py` on the build host — it binds a random port, writes the address to `$TMPDIR/com.francescopio.focusflow-server-addr`, and returns a minimal `CliOptions` payload for the `"options"` JSON-RPC method.
3. Run `cargo build --target aarch64-apple-ios --features tauri/custom-protocol --lib` first (the pre-build script will also do this, but pre-running it makes failures easier to debug).
4. Invoke `xcodebuild` with the new device as the destination, plus `-allowProvisioningDeviceRegistration -allowProvisioningUpdates` to auto-add the device to the team profile. Example:
   ```sh
   xcodebuild -project focus-flow.xcodeproj \
              -scheme focus-flow_iOS \
              -destination 'id=AB7F5155-BCB2-5A1C-ACB6-78F739AA3418' \
              -configuration debug \
              -allowProvisioningDeviceRegistration -allowProvisioningUpdates \
              archive
   ```
5. Export the archive to an IPA and install:
   ```sh
   xcodebuild -exportArchive -archivePath /tmp/build/FocusFlow.xcarchive \
                              -exportPath /tmp/build \
                              -exportOptionsPlist gen/apple/ExportOptions.plist \
                              -allowProvisioningUpdates
   xcrun devicectl device install app --device <UDID> /tmp/build/FocusFlow.ipa
   ```
6. On first launch the user must trust the developer profile: Settings → General → VPN & Device Management → Apple ID → Trust.

### Rust ↔ Swift FFI in Tauri (dlsym, not extern "C")

The Rust crate compiles to a dylib before the iOS app target is built. At that point the Swift/Obj-C++ symbols in `Sources/focus-flow/FFLiveActivityBridge.mm` do not yet exist. Plain `extern "C"` declarations fail at link time with `Undefined symbols`.

**Fix:** resolve at runtime via `dlsym(RTLD_DEFAULT, ...)`:

```rust
// NEVER write byte strings with a trailing \0!
// CString::new(b"ff_live_activity_is_available\0") returns Err(NulError)
// because of the embedded NUL, so dlsym never gets called.
let ptr = unsafe { dlsym(b"ff_live_activity_is_available") };  // CString::new adds the \0
```

The pattern in `app/src-tauri/src/live_activity.rs` is:
- A `OnceLock<LiveActivityFns>` cached at first access.
- Each function is `unsafe extern "C" fn(...) -> ...` typed and looked up by name.
- The Tauri command checks `Some(f) => f()`, returns `false` if `None`.

This pattern is needed for any cross-language FFI where the Swift code is compiled by Xcode, not by Cargo. (`tauri-plugin-notification` does the same thing internally for `UNUserNotificationCenter`.)

### iOS Live Activity + Widget extension gotchas

The `FocusFlowWidgets.appex` extension target is generated by `xcodegen` from `app/src-tauri/gen/apple/project.yml`. To re-emit after editing the yml, run `app/src-tauri/scripts/regen_xcode.sh` (which calls `xcodegen generate`).

Common pitfalls:
- `xcodegen` resolves `path:` entries **relative to the project root (`gen/apple/`)**, not relative to the spec file. Use `path: ../../Sources/focus-flow` to pull sources from outside the project root.
- The `gen/` directory is gitignored. Source-of-truth files inside it (the spec, the Sources Swift/Obj-C, Info.plist files, entitlements) are force-added with `git add -f` (see `app/.gitignore` and the root `.gitignore`).
- The widget's `IPHONEOS_DEPLOYMENT_TARGET` is **17.0** (needed for `containerBackground(for: .widget)`). The main app stays at 14.0.
- `xcodegen` does **not** auto-discover new files added to an already-tracked directory. When you add a new file under `Sources/focus-flow/`, you must either add it explicitly to `project.yml` with `path: Sources/focus-flow` and an `includes:` list, or re-emit the project after a `tauri ios init` (which we don't run by hand).
- `path: Sources` in xcodegen only enumerates the directory **once** at generation time. Adding new files to `Sources/focus-flow/` after a regen is not picked up unless you also re-run `xcodegen generate`.
- `cargo build` of the iOS Rust crate runs **before** the Swift/Obj-C++ files are compiled, so the FFI symbols aren't there yet — see the dlsym section above.

### Backend: per-user scoping (the easy bug to repeat)

Any table that mixes rows from multiple users MUST filter by `user_id` in every query — not just the persistence method but the use case. We had `find_all` on `user_settings` returning rows for every user, plus a PATCH handler that did an existence check across all users. The pattern to enforce:

- Persistence traits expose `find_by_user(user_id, ...)` and `exists_for_user(user_id, ...)`, never a global `find_all`. If the use case actually needs all rows (e.g. for an admin endpoint), make the global query an explicit, separate method.
- HTTP handlers take `Extension<UserSession>` from the auth middleware and thread `user.user_id` into the use case. The auth middleware already populates `UserSession` on the request extension.
- Add a `UNIQUE (user_id, key)` constraint via a migration so a future write can never create a duplicate row, even if the application code regresses.

### Frontend: don't permanently cache a negative value

`liveActivity.ts` originally cached `cachedAvailable` as a module-scope variable. A single failed dlsym lookup (or a not-yet-ready Rust dylib at first launch) would cache `false` for the whole page lifetime, even after the user enabled the permission in iOS Settings. **Use a TTL on the negative cache** (e.g. 30 seconds) so transient failures don't lock the toggle off, but still avoid a flood of `invoke()` calls.

### Docker backend deploy flow (Debian LXC + free Apple ID)

1. Build locally on the Mac for `linux/amd64` (NOT the Mac's native `arm64`):
   ```sh
   docker buildx build --platform linux/amd64 \
                       -f backend/Dockerfile \
                       -t focusflow-backend:latest --load .
   ```
   Note: the Dockerfile expects the **build context to be the repo root**, not `backend/`. The `justfile` recipe `docker-build-backend` was wrong until fixed — it was building from `backend/` with the wrong image tag.
2. Save and scp:
   ```sh
   docker save -o /tmp/focusflow/focusflow-backend.tar focusflow-backend:latest
   scp /tmp/focusflow/focusflow-backend.tar agent@focuscloud:~/focusflow-backend.tar
   ```
3. On the server (user is in the `docker` group but needs sudo for the actual socket; `agent` cannot use `newgrp` interactively):
   ```sh
   echo "developP4s$" | ssh -tt agent@focuscloud \
     'echo "developP4s$" | sudo -S bash -c "
         docker load -i /home/agent/focusflow-backend.tar
         rm /home/agent/focusflow-backend.tar
         cd /home/agent
         docker compose up -d --force-recreate --no-deps backend
     "'
   ```
4. Verify with `curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/api/version`.

### gitignore + force-add for Tauri-generated iOS staging area

The `gen/` directory is ignored, but the source-of-truth files inside it (the `project.yml` spec, the `Sources/focus-flow/*.swift/.mm` files, the `Info.plist` and entitlements) must be tracked. A `!pattern` exception in the parent `.gitignore` does **NOT** work when the rule lives in a child `.gitignore` (the negation must come from the same file). Two clean patterns:

- `!` exceptions in the same `.gitignore` file as the ignoring rule. This works only when the same `.gitignore` file covers both the ignore and the file you want to keep.
- For files that live inside an ignored directory and need to be tracked, **`git add -f path/to/file`** is the cleanest approach. Once force-added, Git tracks them regardless of `.gitignore`.

The `app/.gitignore` ignores `src-tauri/gen/`; we track `gen/apple/project.yml`, the Info.plist / entitlements, and the Swift/Obj-C sources by force-adding them on the initial commit.

### `xcode-select` for iOS builds

For iOS dev on Xcode 27 beta + iOS 27 dev-beta devices, the build still succeeds with **Xcode 26** as the active toolchain:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
cd app && bun run tauri ios build --debug --target aarch64
```

The SDK patches documented in `app/ios-fix.md` are only needed if you switch back to the Xcode 27 beta toolchain. The patches live in `/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/...` and require `sudo` to maintain.

### Debug vs Release iOS build (the localhost:5173 trap)

`bun run tauri ios build --debug` produces a **debug** iOS app. Tauri 2 configures the WKWebView to load `tauri.conf.json > build.devUrl` (default: `http://localhost:5173/`). On iOS, `localhost` is the **device itself**, not your Mac, and iOS's Local Network privacy blocks the connection. The app shows:

> "Failed to request http://localhost:5173/: error sending request for url... did you grant local network permissions?"

**Fix: build a release iOS app** (no `--debug`). Release builds load the bundled static assets from `frontendDist` (`app/build/`) instead of `devUrl`:

```sh
cd app && bun run tauri ios build --target aarch64
xcrun devicectl device install app --device <UDID> \
    app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa
```

The release IPA is smaller (~82 MB vs ~90 MB for debug) and works on any device without local-network gymnastics. If you need hot-reload later, build debug for the iPhone with a working dev server and a reachable `devUrl`, and release for everything else.

### Server-side fact sheet

- Server: `agent@focuscloud` (Debian 13 trixie, 2 CPU / 4 GB / 20 GB).
- sudo password: `developP4s$` (the `$` is literal — pass it via `echo 'developP4s$' | ssh -tt ...`).
- `agent` is in the `docker` group but cannot use `sg docker` over non-interactive SSH. Use `echo "developP4s$" | sudo -S bash -c '...'` for any `docker` command.
- Compose stack: `agent-postgres-1`, `agent-backend-1`, `cloudflared` (Cloudflare tunnel to `focusapi.vixwillems.eu`).
- App data dir: `/home/agent/` (compose file at `/home/agent/docker-compose.yml`, env at `/home/agent/.env`).
- Health: `GET /api/version` and `GET /api-docs/openapi.json` return 200 quickly when the stack is up.
- DB admin from the server: `docker exec agent-postgres-1 psql -U focusflow -d focusflow`.
