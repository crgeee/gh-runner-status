#!/usr/bin/env bats
# Coverage for runner version detection, latest-version caching, and
# update/info/doctor argument handling.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
  TMPDIR_TEST=$(mktemp -d)
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ---------------------------------------------------------------------------
# local_runner_version: pick highest bin.X.Y.Z dir, ignore non-version dirs
# ---------------------------------------------------------------------------

@test "version: empty install dir returns empty" {
  local_runner_install_dir() { echo ""; }
  run local_runner_version "actions.runner.x.y"
  [ -z "$output" ]
}

@test "version: picks the highest bin.X.Y.Z directory" {
  local install
  install=$(mktemp -d)
  mkdir -p "$install/bin.2.333.1" "$install/bin.2.334.0" "$install/bin.2.335.0" "$install/bin"
  local_runner_install_dir() { echo "$install"; }
  run local_runner_version "actions.runner.x.y"
  [ "$output" = "2.335.0" ]
  rm -rf "$install"
}

@test "version: handles installs with only bin/ (no versioned dir)" {
  local install
  install=$(mktemp -d)
  mkdir -p "$install/bin"
  local_runner_install_dir() { echo "$install"; }
  run local_runner_version "actions.runner.x.y"
  [ -z "$output" ]
  rm -rf "$install"
}

@test "version: ignores non-version directories" {
  local install
  install=$(mktemp -d)
  mkdir -p "$install/bin.2.334.0" "$install/_diag" "$install/_work" "$install/bin"
  local_runner_install_dir() { echo "$install"; }
  run local_runner_version "actions.runner.x.y"
  [ "$output" = "2.334.0" ]
  rm -rf "$install"
}

@test "version: install dir with dots in path doesn't break sort" {
  # Reproduces Copilot finding: full-path sort would mis-order.
  local install
  install=$(mktemp -d)
  mv "$install" "${install}.with.dots"
  install="${install}.with.dots"
  mkdir -p "$install/bin.2.333.1" "$install/bin.2.334.0"
  local_runner_install_dir() { echo "$install"; }
  run local_runner_version "actions.runner.x.y"
  [ "$output" = "2.334.0" ]
  rm -rf "$install"
}

# ---------------------------------------------------------------------------
# runner_version_status: ok / outdated / unknown
# ---------------------------------------------------------------------------

@test "version_status: matching versions return ok" {
  latest_runner_version() { echo "2.334.0"; }
  run runner_version_status "2.334.0"
  [ "$output" = "ok" ]
}

@test "version_status: mismatched versions return outdated" {
  latest_runner_version() { echo "2.334.0"; }
  run runner_version_status "2.333.1"
  [ "$output" = "outdated" ]
}

@test "version_status: empty installed returns unknown" {
  latest_runner_version() { echo "2.334.0"; }
  run runner_version_status ""
  [ "$output" = "unknown" ]
}

@test "version_status: empty latest returns unknown" {
  latest_runner_version() { echo ""; }
  run runner_version_status "2.333.1"
  [ "$output" = "unknown" ]
}

# ---------------------------------------------------------------------------
# update arg parsing
# ---------------------------------------------------------------------------

@test "update: rejects unknown options" {
  # Script's top-level parser catches --bogus as an unknown option
  # before update's own subcommand-flag check; either way, exit 2 + a
  # message containing "unknown" is the contract.
  run "$SCRIPT" update --bogus runner-1
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown"* ]]
}

@test "update: rejects multiple runner names" {
  run "$SCRIPT" update runner-1 runner-2
  [ "$status" -eq 2 ]
  [[ "$output" == *"at most one"* ]]
}

@test "update: --check before name parses correctly" {
  # Just verify the parser doesn't reject this combination — won't
  # actually execute since the runner isn't real.
  run "$SCRIPT" update --check actions.runner.fake.runner
  [[ "$output" != *"unknown flag"* ]]
  [[ "$output" != *"at most one"* ]]
}
