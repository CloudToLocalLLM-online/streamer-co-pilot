# AGENTS.md — Streamer Co-Pilot

Flutter desktop app that gives an agent runtime (Hermes Agent / OpenClaw) live-stream co-hosting abilities: OBS control via obs-websocket, Twitch chat (IRC + Helix), stream status, and a local agent API. The app is the "body"; the agent is the brain. Repo: CloudToLocalLLM-online/streamer-co-pilot. License: BSL 1.1.

## Commands

- `flutter pub get` — install deps (Dart SDK ^3.12, Flutter stable 3.44.x per CI)
- `flutter analyze` — lint/static analysis (flutter_lints; config in `analysis_options.yaml`)
- `flutter test` — full test suite (`test/`: unit + widget + integration)
- `flutter test --coverage` — CI runs this and uploads `coverage/`
- `flutter test test/integration/ai_server_test.dart` — run one suite
- `flutter run -d linux` — run on desktop
- `flutter build linux --release` / `flutter build windows --release` — release builds
- Windows installer: `scripts/packaging/build_windows_installer.ps1` (Inno Setup)
- Linux AppImage: `packaging/appimage/build-appimage.sh` (set `OUTPUT_DIR`, see `.github/workflows/release.yml`)

## Architecture

Three layers, all state in Provider `ChangeNotifier`s:

- `lib/providers/obs_controller.dart` — polls OBS every 3s over obs-websocket → `ObsState`
- `lib/platforms/` — platform abstraction (`stream_platform.dart` interface); Twitch implemented as `twitch_platform.dart` + `twitch_irc_client.dart` (chat), `twitch_helix_client.dart` (status/mod), `twitch_auth.dart` (OAuth). YouTube/Kick are future implementations of the same interface.
- `lib/providers/agent_server.dart` — shelf HTTP server on **port 8511**: `GET /state` (unified snapshot), `POST /command`, `GET /overlay` (OBS browser source), `GET /health`, OAuth callback at `/auth/callback`. Renamed from AiServer — never reintroduce "AI" naming (see commit 393fd64).
- `lib/models/`, `lib/tabs/`, `lib/widgets/`, `lib/theme/` — UI layers.

Docs in `docs/`: `ARCHITECTURE.md`, `AGENT-INTERFACE.md` (API contract — keep code in sync with it), `TEST-PLAN.md` (numbered test matrix), `PLATFORM-INTEGRATION.md`.

## Conventions

- Tests mirror lib structure (`test/services/`, `test/widgets/`, etc.); mocking via `mocktail`.
- Commits follow conventional prefixes: `feat:`, `fix:`, `docs:`, `refactor:` — observed in git log.
- CI (`.github/workflows/ci.yml`) gates on analyze → test → builds for linux/windows/macos. Branch pattern `zoidbot/**` also triggers CI.

## Pitfalls

- Port 8511 is fixed and documented everywhere (README, docs, user guide) — don't change it casually; agents configure against it.
- Linux builds need GTK dev deps: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`.
- Twitch OAuth redirect must be `http://localhost:8511/auth/callback` — registered in the Twitch dev console.
- Integration tests named `ai_server_test.dart` are legacy-named; they test `AgentServer`. Don't duplicate.
