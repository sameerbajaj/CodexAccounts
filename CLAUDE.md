# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Codex Accounts** is a macOS menu bar app (SwiftUI) that monitors OpenAI/Codex account usage across multiple accounts. It displays the lowest remaining quota percentage in the menu bar and shows detailed metrics in a popover.

## Build & Verification

**Every code change must pass a local build before pushing:**
```bash
cd CodexAccounts
xcodebuild -project CodexAccounts.xcodeproj -scheme CodexAccounts -configuration Release build
```

If touching packaging/release scripts, also syntax-check:
```bash
bash -n scripts/build-dmg.sh
```

Always report build status explicitly (`BUILD SUCCEEDED` or failure reason) in handoff summaries.

**Build DMG releases:**
```bash
./scripts/build-dmg.sh v1.0.0   # outputs to dist/
```

**Tests:** Unit tests in `CodexAccountsTests/`, UI tests in `CodexAccountsUITests/`. Run via Xcode (no CLI test command currently in use).

## Architecture

### Layers

- **`@main` app** (`CodexAccountsApp.swift`) — Creates `AccountsViewModel`, owns the `MenuBarExtra`, renders `MenuBarLabel` (custom bar icon via `Canvas`)
- **ViewModel** (`ViewModels/AccountsViewModel.swift`) — Single @Observable class owning all state: accounts list, usage data, sort mode, refresh timers, token keep-alive
- **Views** (`Views/`) — Dumb SwiftUI views; no business logic or direct `UserDefaults` access
- **Services** (`Services/`) — Pure `enum` namespaces with `static func` — `CodexAPIService`, `AccountStore`, `AuthFileWatcher`, `UpdateChecker`, `JWTParser`, `SelfUpdater`
- **Models** (`Models/`) — `struct`, `Codable`, value semantics: `CodexAccount`, `AccountUsage`, DTOs in `UsageModels`

### Key Data Flow

**Startup:** `viewModel.setup()` → `AccountStore.load()` → start auto-refresh timer + token keep-alive (every 10 min)

**Refresh cycle:** `refreshAccount()` → `CodexAPIService.fetchUsageWithRefresh()` → on 401, auto-calls `refreshToken()` → updates `usageData`/`accountStatuses` → persists tokens

**Add account:** `startAddingAccount()` starts `AuthFileWatcher` polling `~/.codex/auth.json` every 2s → detects modification after `codex auth` → parses JWT claims via `JWTParser` → saves to `AccountStore`

### Persistence
- Accounts: `~/Library/Application Support/CodexAccounts/accounts.json` (atomic writes)
- Preferences (sort mode, display mode, refresh interval): `UserDefaults` as **stored** `var` properties with `didSet` — never computed getters (breaks `@Observable` reactivity)
- Watched file: `~/.codex/auth.json` (read-only)

## Swift/SwiftUI Conventions

- **`@Observable`** for all view models — never `ObservableObject` / `@Published`
- **`async/await` + `Task {}`** — never Combine or callbacks
- **`@MainActor.run {}`** when surfacing async results to `@Observable` state
- **Timers:** `Timer.scheduledTimer` stored as `var`; invalidate and recreate on interval change — never `Timer.publish`
- **Hover buttons:** use `.onHover` + opacity (`opacity(isHovering ? 1 : 0)`) — never conditionally insert/remove from layout (causes jitter)
- **Menu bar icon:** drawn with `Canvas`/CoreGraphics, bar fill reflects quota level; color: green >40%, orange >15%, red ≤15%

## Things to Avoid

- Do not use `ObservableObject` / `@Published`
- Do not make `UserDefaults`-backed settings as computed properties
- Do not conditionally insert/remove buttons from layout on hover — use opacity
- Do not call `startAutoRefresh()` with a hardcoded interval — read from persisted `refreshInterval`
- Do not reference `lowestRemaining` (old pattern) — use `menuBarDisplayMode` preference
- Do not use `SetFile` for DMG icon flags (absent on CI) — use `xattr` + Python3 fallback

## Distribution

- Builds are signed with **Developer ID Application: Sameer Bajaj (BZ685BB6M6)**, notarized, and stapled via `scripts/build-dmg.sh`
- If no Developer ID is found locally, falls back to unsigned + ad-hoc sign for quick iteration
- CI (`.github/workflows/release-dmg.yml`) triggers on push to `main` (uploads to `latest` release) and on release tags (uploads to that release)
- CI requires these GitHub secrets: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_SIGNING_IDENTITY`, `APPLE_DEVELOPER_TEAM_ID`, `APPLE_ID`, `APPLE_ID_PASSWORD`
- For local notarization, store credentials once: `xcrun notarytool store-credentials "CodexAccounts-Notarize" --apple-id <email> --team-id BZ685BB6M6`
- `scripts/publish-release.sh v1.0.0` creates tag, GitHub release, and triggers CI
