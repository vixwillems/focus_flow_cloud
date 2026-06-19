# AGENTS.md — FocusFlow Cloud

## Overview

Monorepo with three independent projects, coordinated by `just`:

| Project | Stack | Package manager | Entrypoint |
|---------|-------|-----------------|------------|
| `backend/` | Rust (Axum 0.8 + Diesel 2 + Postgres) | Cargo workspace | `backend/src/main.rs` |
| `app/` | SvelteKit SPA + Tauri v2 | Bun | SvelteKit routes; `app/src-tauri/` for native shell |
| `doc/` | Docusaurus v3 | Bun | `doc/` |

Clean architecture: `domain/` ← `application/` ← `adapters/` ← `infrastructure/` (all under `backend/crates/`).

## Essential commands

Run from repo root. `just` is the primary task runner.

```sh
just backend-check       # fmt → clippy → tests (unit + integration, NOT e2e)
just backend-test-e2e    # needs Docker (testcontainers spins up Postgres)
just backend-cov         # coverage via llvm-cov (slow)
just app-check           # svelte-kit sync + svelte-check (type-check only)
just app-dev             # tauri dev (not vite dev)
just app-generate-type   # generates TS types from Rust DTOs via ts-rs
just check-all           # full CI pipeline locally: backend fmt+clippy+cov+build → app check+build
just install             # cargo fetch + bun install for everything
just test-all            # backend tests + app type-check
```

Single-package Cargo commands (run from `backend/`):

```sh
cargo test -p <crate>            # test one crate
cargo test -p adapters --features ts   # regenerate TS types
```

App scripts (run from `app/`):

```sh
bun run dev              # vite dev server on :5173 (no Tauri)
bun run check            # type-check
bun run generate:types   # regenerate TS types from Rust DTOs
bun run tauri:dev        # full Tauri dev with hot-reload
bun run tauri:build      # production Tauri build
```

## Key conventions

- **App is SPA-only**: `ssr = false`, `prerender = false` in `+layout.ts`. Adapter-static with `fallback: 'index.html'`.
- **CI skips `chore: bump` commits** to prevent infinite loops from auto-bump.
- **Version bump**: commits containing `[patch]`, `[minor]`, or `[major]` in the message trigger `bump_version.yaml` workflow. Both `backend/Cargo.toml` and `app/package.json` are bumped in sync.
- **No JS linting/formatter**: only TypeScript strict mode in `tsconfig.json`. No ESLint, Prettier, or Biome.
- **No frontend tests**: no test framework configured in `app/`.
- **Type generation**: `bun run generate:types` runs `cargo test -p adapters --features ts` with `TS_RS_EXPORT_DIR` pointing to `app/src/types/generated/`.
- **Backend E2E tests** need Docker at runtime (testcontainers-managed Postgres).
- **Health check** (Docker): `wget --spider http://localhost:8080/api-docs/openapi.json`.
- **Doc README** (`app/README.md`) is stale — says React/Vite but actual is SvelteKit.
