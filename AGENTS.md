# Repository Guidelines

## Project Structure & Module Organization
This repository is a workspace wrapper around two active submodules:

- `clawconsole/`: Tauri desktop app. Frontend lives in `clawconsole/src/` (React + TypeScript), native desktop code in `clawconsole/src-tauri/` (Rust).
- `clawops/`: Rust service/CLI used for deployment, probe, lifecycle, and gateway operations. Main code is under `clawops/src/`.
- `docs/`: project notes and support pages.
- `packaging/` and `scripts/`: release packaging helpers.
- `output/`: generated artifacts; do not hand-edit.

Keep changes scoped to the relevant submodule. Root-level changes are usually packaging, docs, or release orchestration.

## Build, Test, and Development Commands
- `make build`: build debug artifacts for `clawconsole` and `clawops` into `output/debug/`.
- `make build-release`: build release artifacts into `output/release/`.
- `make package-windows-gnu`: produce `output/ClawStation-windows-x86_64-gnu.zip`.
- `cd clawconsole && npm test`: run frontend tests with Vitest.
- `cd clawconsole/src-tauri && cargo test`: run desktop/backend Rust tests.
- `cd clawops && cargo test`: run ClawOps tests.
- `cd clawconsole && npm run tauri:dev`: start local desktop development.

Prefer `rg` for searches, for example `rg "connect flow" clawconsole/src-tauri/src`.

## Coding Style & Naming Conventions
- TypeScript/TSX: 2-space indentation, existing semicolon-free style, `PascalCase` for React components, `kebab-case` or concise utility filenames such as `wizard-modal.tsx` and `meta.ts`.
- Rust: standard 4-space indentation, `snake_case` for modules/functions, `CamelCase` for structs/enums.
- Follow the surrounding file style instead of reformatting unrelated code.
- Keep comments sparse and only where behavior is non-obvious.

## Testing Guidelines
- Frontend tests live beside the code as `*.test.ts`.
- Rust tests are inline with `#[cfg(test)]` modules.
- Add or update tests for behavior changes, especially around connection flow, credential handling, packaging, and platform-specific logic.
- Run the narrowest relevant test first, then the full submodule suite before handing off.

## Commit & Pull Request Guidelines
- Use short imperative subjects, optionally scoped: `build: ...`, `docs(README): ...`, `Update clawconsole and clawops submodules`.
- Keep commits focused by submodule or concern.
- PRs should describe user-visible impact, list validation steps, and include screenshots/log snippets for UI or connection-flow changes.
- Mention submodule pointer updates explicitly when the root repo changes them.

## Security & Configuration Tips
- Never commit secrets, local keys, or generated files from `output/`.
- Treat `config/shared/credential-secrets.json` and related key material as local-only data.
- When touching SSH, credential, or gateway flows, preserve non-interactive behavior and existing host-key validation rules.
