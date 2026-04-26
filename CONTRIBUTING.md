# Contributing

Thanks for considering a contribution! This is a small bash project — keeping the code easy to read and the dependency surface minimal are explicit goals.

## Quick start

```bash
git clone https://github.com/crgeee/gh-runner-status
cd gh-runner-status

# Install dev tools (one-time)
brew install bats-core shellcheck    # macOS
# or: apt-get install bats shellcheck  # Linux

# Run the suite
bats tests/

# Lint
shellcheck gh-runner-status

# Smoke test against your own repo
./gh-runner-status owner/repo
```

## Style

- **Pure bash 3.2 compatible.** `mapfile`, `${!var@a}`, namerefs, etc. are off-limits because macOS ships bash 3.2.
- **`set -euo pipefail` everywhere.** New code should fail loudly, not silently.
- **Quote your variable expansions.** `"$var"`, not `$var`. shellcheck enforces this.
- **One-line comments for non-obvious whys.** Don't restate the code.
- **Lifecycle scripts of dependencies must be safe to run.** This includes anything you add to bats helper paths.

## Testing

New behavior gets a bats test. Hermetic tests preferred — source the script with `GH_RUNNER_STATUS_NO_MAIN=1` and call functions directly rather than spawning the CLI.

```bash
# Example
@test "validate_repo accepts dots" {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
  run validate_repo "my.org/my.repo"
  [ "$status" -eq 0 ]
}
```

## PR workflow

1. Fork + branch (`git checkout -b feat/your-thing`)
2. Make your change with tests
3. `shellcheck gh-runner-status && bats tests/` — both must pass
4. Open PR. CI runs lint + tests on Ubuntu + macOS automatically
5. After CI green and review, the maintainer merges

## Scope

In scope:
- Bug fixes
- New subcommands that fit the "one CLI command per fleet operation" model
- Additional alert backends (Slack, Discord, email — same API as `notify`)
- Cross-platform improvements (Linux, WSL, BSDs)

Out of scope:
- Persistent daemons / background services
- Anything that requires a runtime beyond bash + standard Unix tools
- Replacing `gh` with a direct API client

If you're not sure, open an issue first.

## Commit messages

Conventional Commits prefixes preferred but not required: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`, `review:`. Imperative mood, focused on the why.

## Security issues

See [SECURITY.md](SECURITY.md). Please don't file public issues for vulnerabilities.
