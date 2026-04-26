# Changelog

All notable changes to `gh-runner-status` are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Interactive REPL mode (`gh runner-status` with no args, in a TTY) with slash commands (`/help`, `/repos`, `/clear`, `/quit`) and short-form aliases (`l`, `r`, `s`, `x`, `n`, `w`)
- `watch [SECONDS]` subcommand: auto-refresh status table on an interval
- Status icons in the table (`✓` online, `✗` offline, `⚠` error). Set `NO_ICONS=1` to disable
- `notify` subcommand sends Telegram alerts when runners go offline or repo lookups fail
- Local runner control: `start`, `stop`, `restart`, `logs` for LaunchAgents (macOS) and systemd services (Linux)
- `local` subcommand: list runners installed on the current machine
- 38 bats tests covering arg parsing, input validation, Telegram config safety, table rendering
- CI on Ubuntu + macOS (shellcheck + bats), informational kcov coverage on Ubuntu

### Security
- Repo names regex-validated before reaching `gh api` (no `../../foo` path traversal)
- Runner names regex-validated to require `actions.runner.<owner>-<repo>.<runner>` form (no `--no-block`/`default.target` reparse)
- Telegram config is **parsed**, never sourced — malicious config cannot run code
- Bot token sent via `curl --config -` (stdin), never lands in argv
- Telegram message body sent via `data-urlencode "text@<tempfile>"`, immune to content with quotes or newlines
- `notify` distinguishes offline vs errored repos and always alerts on total token-expiry failures regardless of `--threshold`

### Performance
- `render_table` uses a single jq pass + awk instead of ~5 jq invocations per row (was 500+ for 100 runners). 0.04s user time for ~10 runners.

## [0.1.0] — 2026-04-26

### Added
- Initial release: list self-hosted runner status across multiple repos with `gh runner-status owner/repo[,...]`
- `--json` flag for scripting
- Config file at `$XDG_CONFIG_HOME/gh-runner-status/repos`
- Colorized status (green/red/yellow) when stdout is a TTY
- Per-repo error isolation (one bad repo doesn't crash the run)
- Parallel API fetches
