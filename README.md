# gh-runner-status

[![CI](https://github.com/crgeee/gh-runner-status/actions/workflows/ci.yml/badge.svg)](https://github.com/crgeee/gh-runner-status/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A `gh` CLI extension that turns your terminal into a full self-hosted Actions runner control plane — see, control, upgrade, and alert on every runner you own, in one command.

<p align="center">
  <img src="docs/screenshot.svg" alt="gh-runner-status terminal screenshot" width="780" />
</p>

```bash
brew install gh jq
gh auth login
gh extension install crgeee/gh-runner-status
```

Three lines and you're running. Linux: `apt-get install -y gh jq` / `dnf install -y gh jq` / `pacman -S github-cli jq`.

## What you get

- **🖥 Live dashboard** — `gh runner-status` opens an auto-refreshing TUI with single-key controls (no Enter). Per-runner CPU, memory, uptime, and runner version all in one view.
- **🔧 Fleet management** — `start` / `stop` / `restart` / `logs` work with **short names** (`restart runner-1`, not the full LaunchAgent label). `doctor` runs a health check; `info NAME` shows the full picture for one runner.
- **⬆️ One-command upgrades** — `update` checks every runner against the latest release and upgrades them in place. Outdated runners are flagged with `*` in the dashboard.
- **➕ Add a runner from scratch** — `add OWNER/REPO` mints a registration token and prints the exact commands for the target machine. `remove` deregisters via the API.
- **📈 Stats & alerts** — `stats` for an aggregate fleet view; `notify` posts a Telegram message when anything goes offline (cron-friendly).
- **⚡ Tab-completion** — included for `gh runner-status` and `gh-runner-status` (subcommands, runner short names, repo names).

Open source (MIT), pure bash (works on macOS default `/bin/bash` 3.2 too), no dependencies beyond `gh` + `jq` + `curl`. Releases are automated via [release-please](https://github.com/googleapis/release-please) — check [the releases page](https://github.com/crgeee/gh-runner-status/releases) for what's new.

## Quick reference

```bash
gh runner-status                              # live dashboard
gh runner-status owner/repo                   # one-off list
gh runner-status doctor                       # health check
gh runner-status update                       # show outdated runners
gh runner-status update runner-1              # actually upgrade one
gh runner-status info  runner-1               # detailed view of one runner
gh runner-status add    acme-corp/api         # register a new runner
gh runner-status remove acme-corp/api foo     # deregister
gh runner-status stats                        # aggregate fleet view
gh runner-status notify                       # Telegram alert if anything offline
```

## Your first runner (zero to running in one command)

Already have `gh-runner-status` installed? Setting up a fresh self-hosted runner is one command:

```bash
gh runner-status setup acme-corp/api
```

That single command:
1. Mints a registration token via the GitHub API
2. Downloads the latest [actions/runner](https://github.com/actions/runner) tarball for your platform
3. Extracts to `~/.gh-runners/acme-corp-api-<hostname>/`
4. Runs `config.sh` non-interactively
5. Installs as a service (LaunchAgent on macOS, systemd on Linux)
6. **Patches `KeepAlive` into the LaunchAgent** so a crashed runner auto-recovers
7. Starts it
8. Polls the GitHub API until the runner reports `online` (up to 30s)
9. Adds the repo to your gh-runner-status config

Customize:

```bash
gh runner-status setup acme-corp/api \
    --name my-runner \
    --labels gpu,linux,x64 \
    --dir /opt/runners/acme-api \
    --yes              # skip the confirmation prompt
```

After it lands, run `gh runner-status doctor` to verify the host is configured for reboot resilience (auto-login, sleep settings, etc.).

## Configure your fleet manually

If you'd rather edit by hand, drop one repo per line in `~/.config/gh-runner-status/repos`:

```
acme-corp/api
acme-corp/web
acme-corp/data
```

Or use `gh runner-status add OWNER/REPO` — it appends the repo to the config and prints the registration steps without auto-installing.

## Dashboard

Run `gh runner-status` with no args (in a terminal) and you land on a live dashboard:

| Key | What it does |
|---|---|
| `r` | Refresh now (instead of waiting for the timer) |
| `c` | Command mode — type any command, Enter to run |
| `a` | Quick path to `add` (pre-fills the prompt with `add `) |
| `h`, `?` | Show help |
| `q`, `Ctrl-D` | Quit |

The dashboard caches data between refreshes — sub-screens (help, command output) redraw instantly without re-hitting the API. Default refresh interval is 30s; `gh runner-status watch 5` opens the same dashboard with a 5-second interval.

## Per-runner metrics

The main `list` table includes **CPU, MEM, UPTIME, and VERSION** automatically for runners installed on this machine. Process metrics are summed across the agent tree (`runsvc.sh` + `Runner.Listener` + active workers), so numbers reflect real usage when a job is running. Outdated versions are marked with a trailing `*`.

```
✓ acme-corp/api  runner-1  online  no   5d 2h  0.0%   53M   2.334.0   linux,x64
✓ acme-corp/api  runner-2  online  yes  5d 2h  42.1%  187M  2.334.0   linux,x64
✗ acme-corp/web  runner-1  offline no   -      -      -     2.333.1*  linux,x64
```

## Reboot resilience

`doctor` doesn't just check that runners are online — it checks the host is configured to *stay* online after a reboot:

- **macOS auto-login** — LaunchAgents only fire on user login. Without auto-login, a headless reboot leaves all runners offline until someone physically signs in. `doctor` flags this with the exact System Settings path to fix it.
- **`pmset` sleep** — if the mac sleeps, runners stop responding. `doctor` checks `sleep=0` and shows the `pmset` command to set it.
- **LaunchAgent `KeepAlive`** — without it, a single Runner.Listener crash leaves you offline. `setup` adds this automatically; `doctor` flags any runner missing it.
- **Linux systemd `Restart=`** — flags runners with `Restart=no` (won't recover from crashes).

```
$ gh runner-status doctor
Health check (latest runner version: 2.334.0)

  ✗ actions.runner.acme-api.runner-1
      - LaunchAgent missing KeepAlive — runner won't auto-restart on crash

Host resilience:
  ✗ auto-login not enabled — runners will NOT auto-start after reboot
      fix: System Settings → Users & Groups → Login Options → Automatic login
  ✓ system sleep disabled (sleep=0)
```

## Update + doctor

```bash
$ gh runner-status update
Checking latest=2.334.0, installed runners:

  actions.runner.acme-corp-api.runner-1   2.334.0  ✓ up-to-date
  actions.runner.acme-corp-api.runner-2   2.334.0  ✓ up-to-date
  actions.runner.acme-corp-web.runner-1   2.333.1  ⚠ outdated

To upgrade an outdated runner: gh runner-status update <name>
```

```bash
$ gh runner-status update runner-1     # actually does it
Upgrade plan for actions.runner.acme-corp-web.runner-1:
  Install dir:  /opt/actions-runner
  Current:      2.333.1
  Latest:       2.334.0

Stopping ...
Downloading actions-runner-linux-x64-2.334.0.tar.gz ...
Extracting into /opt/actions-runner ...
Starting ...
Updated to 2.334.0.
```

`doctor` runs a full health check across the fleet — flags stopped runners, missing install dirs, outdated versions:

```bash
$ gh runner-status doctor
Health check (latest runner version: 2.334.0)

  ✓ actions.runner.acme-corp-api.runner-1
  ✓ actions.runner.acme-corp-api.runner-2
  ✗ actions.runner.acme-corp-web.runner-1
      - not running
      - outdated (2.333.1, latest 2.334.0)

1 issue(s) found across the fleet.
```

## Telegram alerts

Set up the bot once:

```bash
mkdir -p ~/.config/gh-runner-status
cat > ~/.config/gh-runner-status/telegram <<'EOF'
TELEGRAM_BOT_TOKEN=123456:ABC...           # from @BotFather
TELEGRAM_CHAT_ID=-1001234567890            # from @userinfobot
EOF
chmod 600 ~/.config/gh-runner-status/telegram
```

Drop into cron:

```cron
*/15 * * * * you gh runner-status notify >/dev/null 2>&1
```

`--threshold N` only alerts when ≥N runners are offline. Errored repo lookups (e.g. expired token) always alert regardless of threshold — silent failure is the worst outcome.

## Themes

Three themes for the dashboard, table, and prompts:

| Theme | When to use |
|---|---|
| `dark` (default) | Dark-background terminals — bright cyan banner, vivid green/red/yellow status |
| `light` | Light-background terminals — bold blue banner, less dim grey |
| `neon` | Maximum pop — hot pink banner, bright cyan prompts, vivid greens/reds/oranges |

Three ways to set it, in priority order:

```bash
# 1. In the dashboard, press [t] to cycle dark → neon → light → dark
#    (persists automatically)

# 2. CLI subcommand — persists to settings file
gh runner-status theme neon
gh runner-status theme next     # cycle

# 3. Inline env var — wins over the settings file
GH_RUNNER_STATUS_THEME=neon gh runner-status
```

Settings file is `~/.config/gh-runner-status/settings` (key=value format).

Status icons (`✓`/`✗`/`⚠`) prefix each row by default. Set `NO_ICONS=1` to disable for ASCII-only environments or log viewers that don't render unicode.

## Debug logging

If the dashboard misbehaves (unexpected exit, refresh stalls, key presses ignored), enable the debug log to capture events:

```bash
GH_RUNNER_STATUS_DEBUG=1 gh runner-status
# events go to ~/.local/state/gh-runner-status/debug.log
```

Logs key presses, EOF events, refresh cycles, theme cycles, and quit transitions. Strip the env var to disable.

## Shell autocomplete

```bash
echo 'source ~/.local/share/gh/extensions/gh-runner-status/completions/gh-runner-status.bash' >> ~/.bashrc
```

Tab-completes subcommands, runner short names (for `start/stop/restart/logs/info/update`), and configured repos. Works for both `gh runner-status <TAB>` and `gh-runner-status <TAB>`.

## Install + upgrade + uninstall

```bash
gh extension install crgeee/gh-runner-status     # install
gh extension upgrade gh-runner-status            # upgrade
gh extension remove  gh-runner-status            # uninstall
```

The `~/.config/gh-runner-status/` directory survives uninstall so a re-install picks up your fleet.

## Security model

See [SECURITY.md](SECURITY.md). Highlights:

- Repo + runner names regex-validated before reaching `gh api` / `launchctl` / `systemctl` / `tail` (no `../../foo` path traversal, no `--no-block` reparse)
- Telegram config is **parsed** with a key allowlist, never sourced — malicious config can't run code
- Bot token sent via `curl --config -` (stdin), never lands in argv
- `set -euo pipefail` throughout; `EXIT` trap cleans up temp files

Found a security issue? Please don't open a public issue — see [SECURITY.md](SECURITY.md).

## Local control targets

`start`/`stop`/`restart`/`logs`/`update`:
- **macOS** — LaunchAgents at `~/Library/LaunchAgents/actions.runner.*.plist` (the path GitHub's installer uses)
- **Linux** — `systemd` user services or system services named `actions.runner.*.service`

## JSON output

`--json` works on `list`, `local`, `stats`, and `notify` for piping into `jq` or other automation:

```bash
gh runner-status --json | jq '.[] | select(.status == "offline")'
```

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The project is intentionally tiny: pure bash, no build step, dev-only deps are `bats-core` + `shellcheck` (CI installs them automatically).

```bash
git clone https://github.com/crgeee/gh-runner-status
cd gh-runner-status
shellcheck gh-runner-status     # lint
bats tests/                     # 66 hermetic tests
./gh-runner-status owner/repo   # smoke test
```

CI matrix: shellcheck + bats on Ubuntu + macOS bash 5 + macOS bash 3.2 (the system default — Apple froze it at GPLv2). Conventional Commits drive automated releases via release-please.

## License

MIT. See [LICENSE](LICENSE).
