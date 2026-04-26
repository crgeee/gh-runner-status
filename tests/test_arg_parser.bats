#!/usr/bin/env bats
# Argument parser: flags, subcommands, mixed ordering, error handling.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
}

@test "--help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
  [[ "$output" == *"SUBCOMMANDS:"* ]]
}

@test "-h is an alias for --help" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE:"* ]]
}

@test "--version exits 0 with a version string" {
  run "$SCRIPT" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh-runner-status"* ]]
}

@test "rejects unknown options" {
  run "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "missing subcommand arg fails (start)" {
  run "$SCRIPT" start
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires exactly one"* ]]
}

@test "missing subcommand arg fails (stop)" {
  run "$SCRIPT" stop
  [ "$status" -eq 2 ]
}

@test "missing subcommand arg fails (restart)" {
  run "$SCRIPT" restart
  [ "$status" -eq 2 ]
}

@test "missing subcommand arg fails (logs)" {
  run "$SCRIPT" logs
  [ "$status" -eq 2 ]
}

@test "extra subcommand args fail" {
  run "$SCRIPT" start one two
  [ "$status" -eq 2 ]
}

@test "config file not found is a clear error" {
  run "$SCRIPT" --config /tmp/definitely-does-not-exist-xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"config file not found"* ]]
}
