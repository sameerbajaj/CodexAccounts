# Codex Accounts

A macOS menu bar app that tracks [Codex CLI](https://github.com/openai/codex) usage across multiple OpenAI accounts.

## What it does

The Codex CLI has two rate limits: a rolling 5-hour window and a weekly window. When you hit either one, requests start failing. If you juggle multiple OpenAI accounts, it's hard to know at a glance which one still has quota left.

Codex Accounts shows the lowest remaining percentage across all your accounts directly in the menu bar. Click the icon to open a popover with a card for each account. Each card has both usage meters with time-to-reset countdowns, credit balance if your plan has one, and the plan type.

The app watches `~/.codex/auth.json`. When you run `codex auth` to switch accounts, it picks up the new account automatically. Tokens refresh in the background before they expire.

## Requirements

- macOS 15 or later
- [Codex CLI](https://github.com/openai/codex) installed: `npm i -g @openai/codex`
- At least one account authenticated via `codex auth`

## Build

1. Clone this repo
2. Open `CodexAccounts/CodexAccounts.xcodeproj` in Xcode 26 or later
3. In the Signing & Capabilities tab, set your Apple Developer team
4. Build and run

No third-party dependencies.

## Adding accounts

The app detects your current account from `~/.codex/auth.json` on launch. To add another, click "Add Account" in the popover, then in a terminal run:

```
codex logout
codex auth
```

The app watches the auth file and adds the new account automatically.

## Privacy

The only network requests are to `chatgpt.com/backend-api/wham/usage` to fetch usage numbers and `auth.openai.com/oauth/token` to refresh tokens when they expire. No analytics, no telemetry.

Account data (including tokens) is stored locally in `~/Library/Application Support/CodexAccounts/accounts.json`. Nothing else leaves your machine.

## License

MIT
