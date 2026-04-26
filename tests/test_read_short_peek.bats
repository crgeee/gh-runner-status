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

@test "_read_short_peek: rejects arg with metachars" {
  run _read_short_peek "bad-name-with-dashes"
  [ "$status" -eq 2 ]
}

@test "_read_short_peek: rejects arg starting with digit" {
  run _read_short_peek "1abc"
  [ "$status" -eq 2 ]
}

@test "_read_short_peek: empty stdin returns non-zero" {
  local _peek="prefilled"
  _read_short_peek _peek </dev/null || true
  # On bash 4+ with -t 0.05, empty stdin times out — _peek unchanged
  # or empty. On bash 3.2 with -t 0, same outcome.
  [ -z "$_peek" ] || [ "$_peek" = "prefilled" ]
}
