# gh-runner-status

A `gh` CLI extension that shows the status of self-hosted GitHub Actions runners across one or more repositories — at a glance, in your terminal.

```
$ gh runner-status

REPO                  NAME                   STATUS  BUSY  LABELS
-----------------------------------------------------------------------
crgeee/sepa-screener  sepa-mac-1             online  no    self-hosted,macOS,ARM64,sepa
crgeee/dte0           Christophers-Mac-mini  online  no    self-hosted,macOS,ARM64
crgeee/dte0           dte0-mac-2             online  yes   self-hosted,macOS,ARM64
crgeee/dte0           dte0-mac-3             online  no    self-hosted,macOS,ARM64
crgeee/dte0           dte0-mac-4             offline no    self-hosted,macOS,ARM64
```

`STATUS` is colorized green (online), red (offline), yellow (error) when stdout is a TTY.

## Why

If you run several repos with self-hosted runners (matrix builds, multi-machine fleets, etc.), GitHub's UI makes you click into each repo's Settings → Actions → Runners page. This bundles them into one view. Useful when:

- A CI run is hanging — is the runner online?
- You provisioned a runner — did it register?
- A machine rebooted — did all its runners come back?

## Install

```bash
gh extension install crgeee/gh-runner-status
```

To upgrade later:

```bash
gh extension upgrade gh-runner-status
```

## Requirements

- `gh` CLI (already authenticated)
- `jq`
- A token with `repo` scope (already true if you authenticated `gh` against private repos)

## Usage

```bash
# Use the config file
gh runner-status

# Single repo
gh runner-status owner/name

# Multiple repos
gh runner-status owner/repo-a,owner/repo-b
gh runner-status owner/repo-a owner/repo-b

# Custom config
gh runner-status --config ~/myteam-runners.txt

# Raw JSON for scripting
gh runner-status --json | jq '.[] | select(.status == "offline") | .repo'
```

## Config file

Lives at `$XDG_CONFIG_HOME/gh-runner-status/repos` (or `~/.config/gh-runner-status/repos`). One `owner/name` per line; `#` starts a comment.

```
# my fleet
crgeee/sepa-screener
crgeee/dte0

# work
acme-corp/api
acme-corp/web
```

## JSON output

`--json` emits one object per runner (or one error object per failed repo lookup):

```json
[
  {
    "repo": "crgeee/sepa-screener",
    "name": "sepa-mac-1",
    "status": "online",
    "busy": false,
    "os": "macOS",
    "labels": ["self-hosted", "macOS", "ARM64", "sepa"]
  },
  {
    "repo": "private-org/no-access",
    "error": "HTTP 404: Not Found"
  }
]
```

A bad repo doesn't crash the run — its row appears in the output with the error inline.

## Development

```bash
git clone https://github.com/crgeee/gh-runner-status
cd gh-runner-status
./gh-runner-status owner/repo
```

Pure bash + `gh` + `jq`. No build step.

## License

MIT. See [LICENSE](LICENSE).
