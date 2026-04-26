# Changelog

All notable changes to `gh-runner-status` are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
This file is maintained by release-please. Do NOT edit the version
sections below by hand — instead, write Conventional Commit messages
(feat:, fix:, etc.) and the next merge to master will update this
file automatically. The "Unreleased" section is what release-please
will roll into the next tagged release.
-->

## [0.3.2](https://github.com/crgeee/gh-runner-status/compare/v0.3.1...v0.3.2) (2026-04-26)


### Bug Fixes

* dashboard caching + short runner names + shell completion ([#6](https://github.com/crgeee/gh-runner-status/issues/6)) ([8d1d289](https://github.com/crgeee/gh-runner-status/commit/8d1d289eb3505543b26aeabd9e47758936e1f1cb))

## [0.3.1](https://github.com/crgeee/gh-runner-status/compare/v0.3.0...v0.3.1) (2026-04-26)


### Features

* gh-runner-status v0.1.0 ([9f3bf6a](https://github.com/crgeee/gh-runner-status/commit/9f3bf6a54ce7421e066a6c19b33a15b559ef0448))
* live TUI + add/remove + host and runner metrics ([#3](https://github.com/crgeee/gh-runner-status/issues/3)) ([7333c14](https://github.com/crgeee/gh-runner-status/commit/7333c14aec43d38c7ddfaf18150b817c88fd8ac9))
* per-runner metrics in main list + stats subcommand + bash 3.2 CI ([#4](https://github.com/crgeee/gh-runner-status/issues/4)) ([b488d38](https://github.com/crgeee/gh-runner-status/commit/b488d38fdb7b0a55d740629ad7bcb5acbb19f7c6))
* v0.2.0 — subcommands, Telegram alerts, security, tests, CI ([#1](https://github.com/crgeee/gh-runner-status/issues/1)) ([f2935ab](https://github.com/crgeee/gh-runner-status/commit/f2935ab4b4c52ed9bdb23523e97f9e648ac9e07c))

## [Unreleased]

## [0.3.0] — 2026-04-26

### Added
- **Live auto-refreshing dashboard** with single-key controls (`r` refresh, `c` command mode, `/` slash, `a` add, `h` help, `q` quit) — bare `gh runner-status` opens it in a TTY
- **Per-runner CPU and MEM** in the main `list` table for runners installed on this machine, summed across the whole agent process tree (`runsvc.sh` + `Runner.Listener` + active workers)
- `stats` subcommand: aggregate fleet view (online/offline/busy counts, total memory, top labels, OS distribution)
- `add OWNER/REPO [NAME] [LABELS]`: mints a registration token via the GitHub API, appends to the config, prints copy-paste install commands for the target machine
- `remove OWNER/REPO NAME_OR_ID`: deregisters a runner via the API; resolves id↔name so the cleanup hint always uses a valid LaunchAgent label
- `watch [SECONDS] [REPOS...]` subcommand auto-refreshes the dashboard at a custom interval; non-TTY callers (cron, pipes) get a print-and-sleep loop
- `local` subcommand expanded with PID / UPTIME / CPU / MEM / JOBS columns
- Status icons in the table (`✓` online, `✗` offline, `⚠` error). Set `NO_ICONS=1` to disable
- 49 bats tests covering arg parsing, input validation, Telegram config safety, table rendering, and metric formatters
- CI runs the bats suite on Ubuntu + macOS, **plus a second bats run under macOS `/bin/bash` 3.2** to catch bashisms (shellcheck doesn't have version-specific lint)
- kcov coverage on Ubuntu, uploaded as a workflow artifact and to Codecov when a token is set
- Pre-commit `.githooks/pre-commit` integration; SECURITY.md, CONTRIBUTING.md

### Changed
- `gh runner-status` (no args, in a TTY) now opens the live dashboard instead of a passive prompt
- Banner stripped of host uptime/load/mem — was confusing per-runner-vs-host stats; per-runner is what matters
- `JOBS` column dropped from main `list` (the API's `BUSY` is more authoritative); kept in `local` for diagnostic detail

### Security
- Repo names regex-validated before reaching `gh api` (no `../../foo` path traversal)
- Runner names regex-validated to require `actions.runner.<owner>-<repo>.<runner>` form (no `--no-block`/`default.target` reparse); rejects segments starting with `-`
- Telegram config is **parsed**, never sourced — malicious config cannot run code
- Bot token sent via `curl --config -` (stdin), never lands in argv
- Telegram message body sent via `data-urlencode "text@<tempfile>"`, immune to content with quotes or newlines
- `notify` correctly distinguishes offline vs errored repos and always alerts on total token-expiry failures regardless of `--threshold`

### Performance
- `render_table` uses a single jq pass + awk instead of ~5 jq invocations per row (was 500+ for 100 runners). 0.04s user time for ~10 runners.

### Fixed
- `[/]` and `[a]` dashboard pre-fill keys — refactored away from bash-4-only `read -e -i` so they work on macOS default `/bin/bash` 3.2
- `Ctrl-D` now exits the dashboard cleanly (was treated as a timeout, kept refreshing)
- `local` subcommand surfaces errors from `list_local_runners` instead of conflating "OS unsupported" with "no runners installed"
- `[h]elp` added to the dashboard footer hint (was missing)

## [0.1.0] — 2026-04-26

### Added
- Initial release: list self-hosted runner status across multiple repos with `gh runner-status owner/repo[,...]`
- `--json` flag for scripting
- Config file at `$XDG_CONFIG_HOME/gh-runner-status/repos`
- Colorized status (green/red/yellow) when stdout is a TTY
- Per-repo error isolation (one bad repo doesn't crash the run)
- Parallel API fetches
