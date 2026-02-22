# macOS App Development Guidelines

These instructions capture preferred patterns for building and shipping macOS apps
as open-source projects on GitHub without an Apple Developer Program membership.
They should be followed for any new macOS app in this workspace.

---

## Project Structure

```
AppName/
  AppName/
    AppNameApp.swift          # @main entry point
    ContentView.swift         # root view (or MenuBarPopover for menu-bar apps)
    Assets.xcassets/
      AppIcon.appiconset/     # ALL 10 PNG sizes must be populated (see Icons)
    Models/                   # plain Swift value types, Codable where persisted
    Services/                 # networking, file I/O, OS integrations
    ViewModels/               # @Observable classes, one per major screen
    Views/                    # SwiftUI views, one file per component
    Helpers/                  # extensions, utilities
  AppName.xcodeproj/
  scripts/
    build-dmg.sh              # CI build + DMG packaging script
    generate-icon.swift       # programmatic icon generation (Swift + AppKit)
  .github/
    workflows/
      release-dmg.yml         # builds DMG on push to main and on release tags
```

---

## Swift & SwiftUI Conventions

- **Swift 6 / SwiftUI** — target the latest stable Xcode / swift-tools-version.
- **`@Observable`** for all view models — never use `ObservableObject` / `@Published`.
- Settings that must survive restarts live in **`UserDefaults`** via **stored** `var`
  properties with `didSet`, never as computed getters. `@Observable` can only track
  stored properties; computed vars that read `UserDefaults` break reactivity.
- Store user data (accounts, state) in **`~/Library/Application Support/<AppName>/`**
  using a plain `Codable` + `JSONEncoder` pattern. Never use CoreData for simple lists.
- Prefer **`async/await` + `Task {}`** over Combine or callbacks.
- Use **`@MainActor.run {}`** when surfacing async results back to `@Observable` state.
- Timers: use `Timer.scheduledTimer` held as a stored `var`; invalidate and recreate
  when the interval changes. Never use `publisher(for:)` or `Timer.publish`.

---

## Architecture

- One `XxxViewModel` per major feature, injected as `@State` at the scene level and
  passed down as `let` or `@Bindable`.
- Views are dumb — no business logic, no direct `UserDefaults` access, no networking.
- Services are pure functions or `enum` namespaces (`enum FooService { static func … }`).
- Models are `struct`, `Codable`, value semantics only.

---

## Menu Bar Apps

- Use **`MenuBarExtra`** with `.menuBarExtraStyle(.window)`.
- The menu bar label is a separate `struct MenuBarLabel: View` — keep it small, draw
  custom graphics with `Canvas` rather than SF Symbols when you need dynamic state.
- Dynamic icon pattern: draw N "bars" (or dots, rings, etc.) where lit count reflects
  a live metric. Dim unlit segments with `Color.primary.opacity(0.22)` so the shape
  stays readable in both light and dark menu bars.
- Always include a **Settings panel** accessible via a gear button in the footer.
  Settings options use radio-style rows (radio dot + icon + label + description).
- Settings panel sections: at minimum "Display" (what the menu bar shows) and
  "Refresh" (how often data updates: 2 min top-item, 5 min all, manual).
- Footer layout: `[+ Add / primary action]  [spacer]  [gear]  [vX.Y.Z]  [Quit]`.
  The version label taps to open the GitHub releases page.
- Hover state on card rows: use `.onHover` + `@State private var isHovering`.
  Show action buttons at `opacity(isHovering ? 1 : 0)` — never conditionally insert
  them into the layout (causes jitter).
- Context menus on rows use `Menu { } label: { }` with `.menuStyle(.borderlessButton)`
  and `.menuIndicator(.hidden)`. The label is a plain icon in a fixed-size ZStack
  that shows a subtle background fill on hover.

---

## Auto-Updater (no App Store / no notarization)

Every app ships a lightweight GitHub Releases update checker:

```swift
// Services/UpdateChecker.swift
enum UpdateChecker {
    static let githubRepo = "owner/RepoName"   // ← change per project
    static let releasesPage = URL(string: "https://github.com/\(githubRepo)/releases")!

    static func check() async -> UpdateInfo? { … }   // hits GitHub API
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}
```

- Check on app launch (fire-and-forget `Task`), store result in ViewModel.
- Show a non-blocking **green banner** in the popover when an update exists:
  app icon + "Update available — vX.Y.Z" + "Download" button + dismiss ✕.
- Skip pre-releases and any release whose tag is literally `"latest"` (rolling CI build).
- Compare versions numerically by component so `1.10 > 1.9` works correctly.
- The `v1.0` footer label turns green and is always tappable (opens releases page).

---

## Icons

Since there is no Apple Developer account, icons are generated programmatically.

### Xcode asset catalog
`AppIcon.appiconset/Contents.json` must reference all 10 PNG files:
16×16 @1x, 16×16 @2x, 32×32 @1x, 32×32 @2x, 128×128 @1x, 128×128 @2x,
256×256 @1x, 256×256 @2x, 512×512 @1x, 512×512 @2x.

### `scripts/generate-icon.swift`
A `#!/usr/bin/swift` script using `AppKit` + `CoreGraphics` that renders the
1024×1024 source PNG with no external tools. Runs on both local and CI macOS.
Design language: gradient rounded-rect background, white pictogram. Keep it simple —
it will be shown at 16px in the menu bar and Dock.

### CI injection
`build-dmg.sh` checks for `AppIcon.icns` after `xcodebuild`. If missing, it runs
`generate-icon.swift` → `sips` resize → `iconutil` and injects the `.icns` directly
into the built `.app` bundle before packaging.

---

## Distribution: DMG via GitHub Actions

### Signing (no $99 licence)
- Build with `CODE_SIGNING_ALLOWED=NO`.
- After build, ad-hoc sign: `codesign --force --deep --sign - <App.app>`.
- This turns the fatal *"damaged and can't be opened"* error into the softer
  *"unidentified developer"* prompt, which users dismiss with right-click → Open.
- Document this one-time step clearly in the README.

### `scripts/build-dmg.sh` responsibilities (in order)
1. `xcodebuild` with optional `MARKETING_VERSION=$2` for version stamping.
2. Inject `.icns` if missing (see Icons above).
3. Ad-hoc codesign.
4. Copy `.app` to staging dir, add `/Applications` symlink.
5. `hdiutil create -format UDRW` → mount → place `.VolumeIcon.icns` →
   `chflags hidden` it → set `HasCustomIcon` via `xattr` → Finder layout via
   `osascript` → `hdiutil detach`.
6. `hdiutil convert -format UDZO` to final `.dmg`. Remove the temp UDRW file.
   Always normalise the temp DMG path: `hdiutil` appends `.dmg` if the `-o` arg
   lacks it, which causes a mismatch — check with `[[ -f "$path" ]] || path="${path}.dmg"`.

### GitHub Actions workflow (`.github/workflows/release-dmg.yml`)
- Triggers: `push` to `main`, `release` published, `workflow_dispatch`.
- On **push to main**: build with `version_suffix=latest`, upload to a persistent
  `latest` pre-release tag (create it if it doesn't exist).
- On **release tag** (e.g. `v1.2.0`): strip leading `v`, pass as
  `MARKETING_VERSION` to xcodebuild so `CFBundleShortVersionString` matches.
  Upload to that release tag.
- `permissions: contents: write` is required for `gh release upload`.

---

## README Template (for each new app)

```markdown
## Installation
1. Download `AppName-vX.Y.Z.dmg` from [Releases](…)
2. Open the DMG and drag **AppName** to Applications
3. **First launch only:** right-click → Open → "Open Anyway"
   (required because the app is not notarized)

## Updates
The app checks for updates automatically on launch and shows a banner
when a new version is available.
```

---

## Things to Avoid

- **Do not** use `ObservableObject` / `@Published` — use `@Observable`.
- **Do not** make `UserDefaults`-backed settings as computed properties — they
  won't trigger SwiftUI redraws.
- **Do not** conditionally insert/remove buttons from the layout on hover — use
  opacity instead to avoid layout jitter.
- **Do not** call `startAutoRefresh()` from `setup()` with a hardcoded interval —
  read `refreshInterval` from persisted preferences and respect "manual only".
- **Do not** use `SetFile` from Xcode CLT for DMG icon flags — it's absent on
  fresh CI runners. Use `xattr` + Python3 as the fallback.
- **Do not** reference `lowestRemaining` (old pattern) — the menu bar value should
  come from a user-configurable `menuBarDisplayMode` preference.
- **Do not** add `"filename"` keys to `Contents.json` without also committing the
  PNG files themselves — Xcode will silently skip the icon.
