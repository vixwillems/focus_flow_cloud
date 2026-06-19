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
    │   └── focus-flow.xcodeproj
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
| `just docker-build-backend` | `docker build -t focus_flow_cloud:latest .` (from `backend/`) |
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

- **Docker**: `docker-compose.yml` at the repo root runs `postgres:16-bookworm` + the backend image built from `backend/Dockerfile`. Bring it up with `docker compose up -d`; the backend waits for the DB via healthcheck.
- **k8s**: see `k8s/` for manifests. Apply `namespace.yaml` first, then the rest in dependency order.
- **iOS**: see `app/ios-fix.md` for the full step-by-step (Xcode 26 toolchain + iOS 27 device + free Apple ID).

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
