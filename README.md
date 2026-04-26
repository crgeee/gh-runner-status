# gh-runner-status

[![CI](https://github.com/crgeee/gh-runner-status/actions/workflows/ci.yml/badge.svg)](https://github.com/crgeee/gh-runner-status/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A `gh` CLI extension that gives you a single view of self-hosted GitHub Actions runners across multiple repos — and lets you start, stop, restart, tail logs of the ones running on the local machine, and get a Telegram ping when something goes offline. Optional auto-refresh "watch" mode and a Claude-Code-style REPL.

```
$ gh runner-status

  REPO            NAME        STATUS   BUSY  LABELS
-----------------------------------------------------
✓ your-org/api    runner-1    online   no    self-hosted,linux,x64
✓ your-org/api    runner-2    online   yes   self-hosted,linux,x64
✗ your-org/web    runner-1    offline  no    self-hosted,linux,x64
✓ your-org/data   runner-1    online   no    self-hosted,macOS,ARM64
```

`STATUS` is colorized green (online), red (offline), yellow (error) when stdout is a TTY. Status icons (`✓`/`✗`/`⚠`) can be disabled with `NO_ICONS=1`.

## Why

GitHub's UI makes you click into each repo's Settings → Actions → Runners page to see one fleet at a time. This bundles them into one view and adds local control + alerting. Useful when:

- A CI run is hanging — is the runner online?
- You provisioned a runner — did it register?
- A machine rebooted — did all its runners come back?
- You want a midnight cron that pings you if any runner went offline overnight.

## Install

```bash
gh extension install crgeee/gh-runner-status
```

Upgrade later:

```bash
gh extension upgrade gh-runner-status
```

## Requirements

| Dep | Why |
|---|---|
| `gh` | Already authenticated via `gh auth login` |
| `jq` | JSON parsing |
| `curl` | Only required if using `notify` |
| `bash` 3.2+ | Default macOS bash works |

A `gh` token with `repo` scope (the default for `gh auth login` against private repos).

Local control (`start`/`stop`/`restart`/`logs`) targets:
- macOS — LaunchAgents at `~/Library/LaunchAgents/actions.runner.*.plist` (the path GitHub's installer uses)
- Linux — `systemd` user services or system services named `actions.runner.*.service`

## Usage

### List status

```bash
gh runner-status                                # repos from config file
gh runner-status owner/repo                     # one-off
gh runner-status owner/repo-a,owner/repo-b      # comma-separated
gh runner-status owner/repo-a owner/repo-b      # space-separated
gh runner-status --json | jq '.[] | select(.status == "offline")'
```

### Local runner control

```bash
gh runner-status local                          # list runners on this machine
gh runner-status start   actions.runner.org-repo.name
gh runner-status stop    actions.runner.org-repo.name
gh runner-status restart actions.runner.org-repo.name
gh runner-status logs    actions.runner.org-repo.name
```

The runner name is the LaunchAgent label on macOS (`actions.runner.OWNER-REPO.NAME`) or the systemd service name on Linux. `gh runner-status local` shows you the names.

### Watch mode

Refresh the table on an interval — useful while a deploy is in flight, or when you want a permanent terminal pane showing fleet health.

```bash
gh runner-status watch                          # 30s refresh (default)
gh runner-status watch 5                        # 5s refresh
gh runner-status watch 60 your-org/api          # specific repos only
```

`Ctrl-C` to exit.

### Interactive REPL

Run `gh runner-status` with no args (in a terminal) and you drop into a persistent prompt with slash commands and short aliases — same UX as Claude Code.

```
▸ gh-runner-status v0.2.0
type /help for commands • Ctrl-D to exit

❯ list
  REPO            NAME        STATUS   BUSY  LABELS
-----------------------------------------------------
✓ your-org/api    runner-1    online   no    self-hosted,linux,x64
✗ your-org/web    runner-1    offline  no    self-hosted,linux,x64

❯ restart actions.runner.your-org-web.runner-1
restarted: actions.runner.your-org-web.runner-1

❯ /repos
# /home/you/.config/gh-runner-status/repos
your-org/api
your-org/web

❯ /quit
bye!
```

Aliases inside the REPL: `l`/`ls` → `list`, `r` → `restart`, `s` → `start`, `x` → `stop`, `n` → `notify`, `w` → `watch`. Up-arrow recalls history within the session.

### Telegram alerts

```bash
gh runner-status notify              # check; alert if any runner is offline/errored
gh runner-status notify --threshold 2  # only alert if 2+ runners are offline
```

Set up the bot once:

```bash
mkdir -p ~/.config/gh-runner-status
cat > ~/.config/gh-runner-status/telegram <<'EOF'
TELEGRAM_BOT_TOKEN=123456:ABC...           # from @BotFather
TELEGRAM_CHAT_ID=-1001234567890            # from @userinfobot or your chat
EOF
chmod 600 ~/.config/gh-runner-status/telegram
```

Or pass via env: `TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... gh runner-status notify`.

Then drop it in cron / launchd / a systemd timer:

```cron
# /etc/cron.d/gh-runner-watch  — every 15 minutes
*/15 * * * * cgonzalez gh runner-status notify >/dev/null 2>&1
```

Errored repo lookups (e.g., expired token) are treated as a critical condition and always alert, regardless of `--threshold`.

## Config file

Lives at `$XDG_CONFIG_HOME/gh-runner-status/repos` (or `~/.config/gh-runner-status/repos`). One `owner/name` per line; `#` starts a comment.

```
# my fleet
your-org/api
your-org/web

# data team
your-org/data-pipeline
```

## JSON output

`--json` emits one object per runner (or one error object per failed repo lookup):

```json
[
  {
    "repo": "your-org/api",
    "name": "runner-1",
    "status": "online",
    "busy": false,
    "os": "Linux",
    "labels": ["self-hosted", "linux", "x64"]
  },
  {
    "repo": "private-org/no-access",
    "error": "HTTP 404: Not Found"
  }
]
```

A bad repo doesn't crash the run — its row appears with the error inline.

## Security model

This is a public tool that handles a Telegram bot token (sensitive) and shells out to `gh`, `curl`, `launchctl`, and `systemctl`. The script is hardened against the obvious threats:

- **Repo names and runner names are regex-validated** before reaching `gh api`, `launchctl`, `systemctl`, or `tail` so a name like `--no-block` or `../../foo` is rejected at the boundary.
- **Telegram config is parsed, not sourced.** A malicious `~/.config/gh-runner-status/telegram` file cannot run code — only `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` keys are extracted from a key=value parser.
- **Bot token never lands in argv.** The Telegram POST is sent via `curl --config -` (stdin), so `ps auxe` from another user can't see it.
- **`set -euo pipefail`** throughout; `EXIT` trap cleans up the temp directory; failures don't mask silently.
- **No `eval`, no `bash -c "$user_input"`, no `source` of untrusted files.**

If you find a security issue, open an issue or PR — happy to credit reporters.

## Development

```bash
git clone https://github.com/crgeee/gh-runner-status
cd gh-runner-status
shellcheck gh-runner-status        # lint
bats tests/                        # 32 tests covering arg parsing,
                                   # validation, telegram-config safety,
                                   # and table rendering
./gh-runner-status owner/repo      # smoke test
```

CI runs shellcheck + bats on Linux + macOS for every push and PR. Coverage is generated with `kcov` and uploaded as a workflow artifact (and to Codecov when a token is set).

Pure bash. No build step. No dependencies beyond `gh` + `jq` + `curl` (which you almost certainly already have). Dev-only: `bats-core` + `shellcheck` + `kcov` (CI installs them automatically).

## License

MIT. See [LICENSE](LICENSE).
