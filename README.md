# FocusFlow

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Backend CI](https://github.com/vixwillems/focus_flow_cloud/actions/workflows/ci-backend.yaml/badge.svg)](https://github.com/vixwillems/focus_flow_cloud/actions)
[![App CI](https://github.com/vixwillems/focus_flow_cloud/actions/workflows/ci-app.yaml/badge.svg)](https://github.com/vixwillems/focus_flow_cloud/actions)
[![codecov](https://codecov.io/gh/vixwillems/focus_flow_cloud/branch/master/graph/badge.svg)](https://codecov.io/gh/vixwillems/focus_flow_cloud)

> **This is a personal fork** of [francesco-gaglione/focus_flow_cloud](https://github.com/francesco-gaglione/focus_flow_cloud) by [@vixwillems](https://github.com/vixwillems).
> All credit for the original design, architecture, and implementation goes to [Francesco Gaglione](https://github.com/francesco-gaglione).
> This fork may contain local modifications. For the canonical project, documentation, and upstream releases, please visit the [original repository](https://github.com/francesco-gaglione/focus_flow_cloud).

A self-hostable Pomodoro + task management ecosystem: a Rust backend with a real-time WebSocket API, and a native cross-platform client built with Tauri v2 + SvelteKit that runs on macOS, Windows, Linux, Android, and iOS.

> **Upstream Documentation**: [https://francesco-gaglione.github.io/focus_flow_cloud/](https://francesco-gaglione.github.io/focus_flow_cloud/)

## Screenshots

<table>
  <tr>
    <td align="center"><b>Tasks</b></td>
    <td align="center"><b>Calendar (Month)</b></td>
    <td align="center"><b>Calendar (Week)</b></td>
    <td align="center"><b>Statistics</b></td>
    <td align="center"><b>Timer</b></td>
  </tr>
  <tr>
    <td><img src="doc/static/img/screenshots/tasks.png" alt="Tasks" width="100%" /></td>
    <td><img src="doc/static/img/screenshots/calendar_month.png" alt="Calendar Month" width="100%" /></td>
    <td><img src="doc/static/img/screenshots/calendar_week.png" alt="Calendar Week" width="100%" /></td>
    <td><img src="doc/static/img/screenshots/stats.png" alt="Statistics" width="100%" /></td>
    <td><img src="doc/static/img/screenshots/timer.png" alt="Timer" width="100%" /></td>
  </tr>
</table>

## What is FocusFlow?

FocusFlow is a complete ecosystem for time management using the Pomodoro technique. It allows you to:

- **Track Sessions**: Manage work and break intervals; review and edit them later.
- **Sync in Real-time**: Multi-device state via WebSockets; the timer state is broadcast to every client you log in on.
- **Organize Tasks**: Categorize, prioritize, and schedule your to-dos.
- **Analyze Productivity**: Stats, calendar heatmaps, and per-user totals.
- **Memorize with Flashcards**: Spaced-repetition decks with due-card reviews and activity heatmaps.
- **Self-host, your data**: Run the backend wherever you want. The client points at your URL on first launch — no cloud account required.
- **Native Experience**: macOS / Windows / Linux / Android / iOS, distributed as a thin native shell around the same SvelteKit SPA.

This project was originally created by [Francesco Gaglione](https://github.com/francesco-gaglione) for personal use and shared as open source.

## Project Structure

This is a monorepo containing:

- **[`backend/`](backend/)** — Rust server (Axum 0.8 + Diesel 2 + Postgres), clean-architecture layout (`domain` → `application` → `adapters` → `infrastructure`).
- **[`app/`](app/)** — SvelteKit SPA (Tailwind v4 + Skeleton UI) wrapped in a Tauri v2 native shell. One codebase for desktop + iOS + Android.
- **[`doc/`](doc/)** — Docusaurus v3 documentation site.
- **[`k8s/`](k8s/)** — Kubernetes manifests for self-hosting.
- **`docker-compose.yml`** — Two-service compose: `postgres:16-bookworm` + the backend image, with a healthcheck-gated startup.

## Features

### Backend

- **Pomodoro Session Tracking** — Core logic for timer state, with manual + automatic session creation.
- **Focus session CRUD** — List, edit, and delete past sessions via the API.
- **Real-time Synchronization** — WebSocket broadcasting of timer state to all connected clients.
- **RESTful API** — Documented via OpenAPI / Swagger UI at `/api-docs/`.
- **Admin endpoints** — `GET /api/users`, `PUT /api/users/{id}` (rename + role), `DELETE /api/users/{id}`, `PUT /api/users/{id}/password`, `GET /api/users/{id}/stats`.
- **Flashcards** — Decks, folders, cards, due-card queries, reviews, and stats + heatmap; JSON export and import.
- **Push Notifications** — Reminder delivery via Web Push (VAPID).
- **Clean architecture** — `domain` / `application` / `adapters` / `infrastructure` separation; use cases are individually registered and wired into `AppState`.
- **Auto migrations** — Diesel migrations are embedded at build time and run on startup.

### App

- **Pomodoro Timer** — Live timer with classic 25 / 5 / 15 defaults (configurable in Settings). Auto-detects the current session type from the backend.
- **Task Management** — Create, edit, prioritize, schedule, and categorize tasks.
- **Calendar** — Month and week views with time-positioned task blocks colored by priority / category.
- **Statistics** — Productivity insights, focus time, peak hours, per-user totals.
- **Sessions Page** — Browse, edit, and delete past focus sessions (click to edit duration, type, or notes).
- **Flashcards** — Decks, folders, card creation, daily review queue, and per-deck stats. Import / export the whole library as JSON.
- **Settings** — Edit default Pomodoro durations and app preferences.
- **Admin Panel** (role-gated) — User list, create / rename / role-toggle / delete, password reset, per-user session stats.
- **Native Notifications** — System-level notifications for Pomodoro transitions and reminders.
- **Cross-platform** — macOS, Windows, Linux, Android, iOS — pre-built binaries via [Releases](https://github.com/vixwillems/focus_flow_cloud/releases).
- **Self-host friendly** — On first launch, the user enters the backend URL; no config files needed.

## Getting Started

### Self-Hosting with Docker (recommended)

The repo ships a `docker-compose.yml` that runs PostgreSQL and the backend with a healthcheck-gated dependency.

1. Create a `.env` next to `docker-compose.yml`:

   ```env
   POSTGRES_PASSWORD=secure_pw
   JWT_SECRET=change_me_to_a_long_random_string
   VAPID_PRIVATE_KEY=your_vapid_private_key
   ADMIN_USERNAME=admin
   ADMIN_PASSWORD=admin
   CORS_ORIGIN=*
   ```

2. `docker compose up -d` — PostgreSQL starts, the backend waits for the DB to be ready, then binds on `:8080`.
3. Download a client binary from [Releases](https://github.com/vixwillems/focus_flow_cloud/releases), install, and enter your server URL on first launch.

> **VAPID private key**: the placeholder works for the backend to start, but push notifications will fail until you provide a real key. See the [Web Push docs](https://web.dev/articles/push-notifications-web-push-protocol) for generating one.

### Self-Hosting with Kubernetes

Kubernetes manifests live in [`k8s/`](k8s/). Apply the namespace first, then the rest in dependency order:

```bash
cd k8s
kubectl apply -f namespace.yaml
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-config.yaml
kubectl apply -f postgres-volume.yaml
kubectl apply -f postgres.yaml
kubectl apply -f focus-flow-cloud-secret.yaml
kubectl apply -f focus-flow-cloud-config.yaml
kubectl apply -f focus-flow-cloud.yaml
```

### Building the iOS app

iOS builds need a Mac with Xcode installed. The build path is non-trivial because of the iOS 27 dev-beta toolchain; full step-by-step in **[`app/ios-fix.md`](app/ios-fix.md)**. TL;DR:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # Xcode 26
cd app
bun run tauri ios build --debug --target aarch64
# -> app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa
xcrun devicectl device install app app/src-tauri/gen/apple/build/arm64/FocusFlow.ipa
```

Free Apple ID certs expire every 7 days — just rebuild and reinstall.

## Downloading the App

Pre-built binaries are available on the [GitHub Releases](https://github.com/vixwillems/focus_flow_cloud/releases) page:

| Platform | File |
| :--- | :--- |
| macOS (Apple Silicon) | `.dmg` |
| macOS (Intel) | `.dmg` |
| Linux | `.deb` / `.AppImage` |
| Windows | `.exe` / `.msi` |
| Android | `.apk` |
| iOS | `FocusFlow.ipa` (sideload with `devicectl` or Xcode) |

On first launch, enter your backend server URL to connect.

## Development Setup

We use [`just`](https://github.com/casey/just) to manage commands for the entire repository.

**Prerequisites**: Rust 1.77+, [Bun](https://bun.sh/), Docker, [Tauri prerequisites](https://tauri.app/start/prerequisites/) for your platform, PostgreSQL client (or just Docker).

### Quick commands

| Command | Description |
| :--- | :--- |
| `just install` | Fetch Cargo + Bun deps for the whole repo |
| `just backend-run` | Run the Rust backend locally |
| `just backend-test` | Run backend unit + integration tests |
| `just backend-check` | fmt + clippy + test (no e2e, no coverage) |
| `just backend-cov` | Coverage via `cargo llvm-cov` (slow) |
| `just app-dev` | Tauri dev (desktop, with hot-reload) |
| `just app-check` | Svelte type-check |
| `just test-all` | Backend tests + app type-check |
| `just check-all` | Full CI pipeline locally (fmt + clippy + cov + build + app check + build) |
| `just docker-build-backend` | Build the backend Docker image |
| `just bump-patch` / `bump-minor` / `bump-major` / `bump-auto` | Bump both versions in lockstep, regenerate CHANGELOG, tag |

### 1. Setup Backend (Local)

1. **Environment**: `backend/.env` is required. Copy from `backend/.env.example`.
2. **Database**: easiest is `docker compose up -d postgres` (the compose file has just the DB if you comment out the backend service), or run a local Postgres and point `DATABASE_BASE_URL` at it.
3. Migrations are automatic — they run on backend startup. (No `diesel migration run` step needed.)
4. `just backend-run`

### 2. Setup App (Local)

```bash
cd app
bun install
bun run tauri:dev   # launches Tauri desktop with hot-reload
```

On first launch, enter `http://localhost:8080` as the server URL.

### 3. Regenerate TS types from Rust DTOs

After changing a `#[derive(TS)]` struct in the backend:

```bash
cd app
bun run generate:types
```

## Contributing

Contributions are welcome! This monorepo allows you to work on the full stack.

- If you change the API, regenerate the TS types and update the app client.
- Run `just check-all` before submitting a PR.
- Follow the backend's clean-architecture pattern when adding features — every new use case is one struct in `application/`, one HTTP handler in `adapters/`, and one wiring line in `infrastructure/src/setup/`.

### Commit Guidelines

We strictly follow **[Conventional Commits](https://www.conventionalcommits.org/)** to manage versioning and changelogs automatically.

**Format:**

```text
<type>(<scope>): <subject>
```

**Common Types:**

- `feat`: A new feature (**Minor** version bump)
- `fix`: A bug fix (**Patch** version bump)
- `docs`, `chore`, `refactor`, `test`: Other changes (no version bump)

> [!IMPORTANT]
> **Breaking Changes**
> If your changes break backward compatibility, you **MUST** indicate it to trigger a **MAJOR** version bump.
>
> You can do this by adding a `!` after the type:
>
> ```text
> feat!: remove legacy API endpoints
> ```

## Architecture notes

- The backend keeps `domain` free of I/O and async; everything async / DB-shaped lives in `adapters` and `infrastructure`.
- The app is a single SvelteKit SPA; one bundle serves desktop, mobile, and the embedded Tauri webview.
- Diesel migrations are embedded at compile time via `embed_migrations!`, so a freshly-built backend always knows how to bring an empty DB up to schema.
- iOS releases are produced by the same `bun run tauri ios build` command as any other target — no separate mobile codebase.

## Credits

This project is a fork of [FocusFlow](https://github.com/francesco-gaglione/focus_flow_cloud) by [Francesco Gaglione](https://github.com/francesco-gaglione), who designed and built the original application. Please consider supporting his work:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=flat&logo=buy-me-a-coffee-icon)](https://buymeacoffee.com/francescogaglione)

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
