#!/usr/bin/env bats
# Table rendering: source the script and invoke render_table directly
# with synthetic input, no network.

setup() {
  # Source-load the script. Guard prevents `main "$@"` from running.
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
}

@test "renders header columns" {
  rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":["x"]}'
  run render_table "$rows"
  [ "$status" -eq 0 ]
  [[ "$output" == *"REPO"* ]]
  [[ "$output" == *"NAME"* ]]
  [[ "$output" == *"STATUS"* ]]
  [[ "$output" == *"BUSY"* ]]
  [[ "$output" == *"LABELS"* ]]
}

@test "shows '(no runners found)' on empty input" {
  run render_table ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"no runners found"* ]]
}

@test "renders busy=yes when .busy is true" {
  rows='{"repo":"a/b","name":"r1","status":"online","busy":true,"labels":[]}'
  run render_table "$rows"
  [[ "$output" == *"yes"* ]]
}

@test "renders busy=no when .busy is false" {
  rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":[]}'
  run render_table "$rows"
  [[ "$output" == *"no"* ]]
}

@test "renders error rows with error string in NAME column" {
  rows='{"repo":"a/b","error":"HTTP 404"}'
  run render_table "$rows"
  [[ "$output" == *"HTTP 404"* ]]
  [[ "$output" == *"error"* ]]   # status defaults to 'error'
}

@test "joins multiple labels with comma" {
  rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":["x","y","z"]}'
  run render_table "$rows"
  [[ "$output" == *"x,y,z"* ]]
}

@test "handles multiple rows with varying widths" {
  rows='{"repo":"short/r","name":"a","status":"online","busy":false,"labels":["x"]}
{"repo":"much-longer-org/repo-name","name":"runner-with-a-long-name","status":"offline","busy":false,"labels":["x"]}'
  run render_table "$rows"
  [ "$status" -eq 0 ]
  [[ "$output" == *"short/r"* ]]
  [[ "$output" == *"much-longer-org/repo-name"* ]]
  [[ "$output" == *"runner-with-a-long-name"* ]]
}
