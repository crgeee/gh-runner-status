#!/usr/bin/env bats
# Input validation: regex guards on repo names and runner names.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
}

@test "rejects path traversal in repo name" {
  run "$SCRIPT" "owner/../../etc/passwd"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid repo"* ]]
}

@test "rejects repo with query string" {
  run "$SCRIPT" 'owner/repo?leak=1'
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid repo"* ]]
}

@test "rejects repo with fragment" {
  run "$SCRIPT" 'owner/repo#frag'
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid repo"* ]]
}

@test "rejects empty repo segments" {
  run "$SCRIPT" "owner/"
  [ "$status" -eq 2 ]
}

@test "rejects single-segment repo" {
  run "$SCRIPT" "owner"
  [ "$status" -eq 2 ]
}

@test "accepts valid repo shape (network call may fail; we only check validation)" {
  # We don't actually mock gh here; just verify validation doesn't reject.
  # If gh is unauthenticated this errors AFTER validation, which is fine.
  run "$SCRIPT" "valid-owner/valid-repo"
  # Either succeeds (real call) or fails for non-validation reason; in
  # both cases the validation message must NOT appear.
  [[ "$output" != *"invalid repo"* ]]
}

@test "rejects runner name with shell-flag prefix" {
  run "$SCRIPT" restart -- "--no-block"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid runner name"* ]]
}

@test "rejects runner name that's a systemd target" {
  run "$SCRIPT" restart -- "default.target"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid runner name"* ]]
}

@test "rejects runner name without actions.runner. prefix" {
  run "$SCRIPT" stop "evil-name"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid runner name"* ]]
}

@test "accepts canonical runner name shape" {
  # Will fail because the LaunchAgent doesn't exist, but should pass the
  # regex check (we look for the validation message specifically).
  run "$SCRIPT" stop "actions.runner.fake-org.runner-1"
  [[ "$output" != *"invalid runner name"* ]]
}

@test "--threshold rejects non-numeric" {
  run "$SCRIPT" notify --threshold abc
  [ "$status" -eq 2 ]
  [[ "$output" == *"non-negative integer"* ]]
}

@test "--threshold accepts zero" {
  # Zero should parse successfully even if notify itself errors out
  # later for missing config — we only check the parser.
  run "$SCRIPT" notify --threshold=0 owner/repo
  [[ "$output" != *"non-negative integer"* ]]
}
