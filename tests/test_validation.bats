#!/usr/bin/env bats
# Input validation: regex guards on repo names and runner names.
# Source-loaded so we can call validate_* directly without hitting `gh`.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
}

@test "validate_repo rejects path traversal" {
  run validate_repo "owner/../../etc/passwd"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid repo"* ]]
}

@test "validate_repo rejects query string" {
  run validate_repo 'owner/repo?leak=1'
  [ "$status" -eq 1 ]
}

@test "validate_repo rejects fragment" {
  run validate_repo 'owner/repo#frag'
  [ "$status" -eq 1 ]
}

@test "validate_repo rejects empty repo segments" {
  run validate_repo "owner/"
  [ "$status" -eq 1 ]
}

@test "validate_repo rejects single-segment repo" {
  run validate_repo "owner"
  [ "$status" -eq 1 ]
}

@test "validate_repo accepts canonical owner/repo" {
  run validate_repo "valid-owner/valid-repo"
  [ "$status" -eq 0 ]
}

@test "validate_repo accepts dots and underscores" {
  run validate_repo "my.org/my_repo.name-1"
  [ "$status" -eq 0 ]
}

@test "validate_runner_name rejects shell-flag prefix" {
  run validate_runner_name "actions.runner.--no-block"
  [ "$status" -eq 1 ]
}

@test "validate_runner_name rejects systemd target" {
  run validate_runner_name "default.target"
  [ "$status" -eq 1 ]
}

@test "validate_runner_name rejects single-segment after prefix" {
  run validate_runner_name "actions.runner.foo"
  [ "$status" -eq 1 ]
}

@test "validate_runner_name rejects without actions.runner. prefix" {
  run validate_runner_name "evil-name"
  [ "$status" -eq 1 ]
}

@test "validate_runner_name accepts canonical shape" {
  run validate_runner_name "actions.runner.fake-org.runner-1"
  [ "$status" -eq 0 ]
}

@test "validate_runner_name accepts owner-with-dots" {
  run validate_runner_name "actions.runner.my.org-my-repo.runner-1"
  [ "$status" -eq 0 ]
}

@test "CLI: --threshold rejects non-numeric" {
  run "$SCRIPT" notify --threshold abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"non-negative integer"* ]]
}

@test "CLI: --threshold without value gives clear error" {
  run "$SCRIPT" notify --threshold
  [ "$status" -eq 2 ]
  [[ "$output" == *"non-negative integer"* ]]
}

@test "CLI: --config without value gives clear error" {
  run "$SCRIPT" --config
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires a value"* ]]
}
