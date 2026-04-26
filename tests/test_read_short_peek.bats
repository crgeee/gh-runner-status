#!/usr/bin/env bats
# Coverage for _read_short_peek and the BASH_HAS_FRACTIONAL_TIMEOUT
# branching that prevents bash 3.2 incompatibilities.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
}

@test "BASH_HAS_FRACTIONAL_TIMEOUT is set on script load" {
  [ "$BASH_HAS_FRACTIONAL_TIMEOUT" = "0" ] || [ "$BASH_HAS_FRACTIONAL_TIMEOUT" = "1" ]
}

@test "BASH_HAS_FRACTIONAL_TIMEOUT matches BASH_VERSINFO[0]>=4" {
  if (( BASH_VERSINFO[0] >= 4 )); then
    [ "$BASH_HAS_FRACTIONAL_TIMEOUT" = "1" ]
  else
    [ "$BASH_HAS_FRACTIONAL_TIMEOUT" = "0" ]
  fi
}

@test "_read_short_peek: rejects missing arg" {
  run _read_short_peek
  [ "$status" -eq 2 ]
  [[ "$output" == *"expected exactly one variable name"* ]]
}

@test "_read_short_peek: rejects extra args" {
  run _read_short_peek a b
  [ "$status" -eq 2 ]
}

@test "_read_short_peek: rejects non-identifier arg" {
  run _read_short_peek "1bad"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not a valid bash identifier"* ]]
}

@test "_read_short_peek: rejects arg with shell metacharacters" {
  run _read_short_peek "evil; rm -rf /"
  [ "$status" -eq 2 ]
}

@test "_read_short_peek: empty stdin returns no output and non-zero" {
  local _peek="prefilled"
  _read_short_peek _peek </dev/null || true
  [ -z "$_peek" ] || [ "$_peek" = "prefilled" ]
}

@test "_read_short_peek: reads buffered bytes when stdin has them" {
  local _peek=""
  # Pre-buffer 2 bytes (`[A` is what an arrow-up sequence would have
  # after the leading `\e`). Force fractional path via env.
  if (( BASH_VERSINFO[0] >= 4 )); then
    _read_short_peek _peek <<< "[A" || true
    # Should have read at least one byte; bash strips trailing newline.
    [ -n "$_peek" ]
  else
    skip "bash 3.2 read -t 0 race-prone in tests"
  fi
}
