#!/usr/bin/env bats
# Coverage for short-name resolution + dashboard cache logic, both
# added in fix/dashboard-cache-and-perf.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
}

# ---------------------------------------------------------------------------
# _resolve_runner_label: short-name → full-label resolution
# ---------------------------------------------------------------------------

@test "resolve: full label passes through unchanged" {
  # Short-circuit on `actions.runner.*` input — no list_local_runners call.
  run _resolve_runner_label "actions.runner.acme-api.runner-1"
  [ "$status" -eq 0 ]
  [ "$output" = "actions.runner.acme-api.runner-1" ]
}

@test "resolve: unique short name resolves to full label" {
  list_local_runners() {
    echo "actions.runner.acme-api.runner-1"
    echo "actions.runner.acme-web.runner-2"
  }
  run _resolve_runner_label "runner-1"
  [ "$status" -eq 0 ]
  [ "$output" = "actions.runner.acme-api.runner-1" ]
}

@test "resolve: ambiguous short name lists candidates" {
  list_local_runners() {
    echo "actions.runner.acme-api.runner-1"
    echo "actions.runner.acme-web.runner-1"
  }
  run _resolve_runner_label "runner-1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ambiguous"* ]]
  [[ "$output" == *"actions.runner.acme-api.runner-1"* ]]
  [[ "$output" == *"actions.runner.acme-web.runner-1"* ]]
}

@test "resolve: no match produces a clear error" {
  list_local_runners() {
    echo "actions.runner.acme-api.runner-1"
  }
  run _resolve_runner_label "nonexistent"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no local runner"* ]]
}

@test "resolve: propagates list_local_runners errors (e.g. unsupported OS)" {
  list_local_runners() {
    echo "error: local runner control not supported on this OS" >&2
    return 1
  }
  run _resolve_runner_label "runner-1"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]]
}

# ---------------------------------------------------------------------------
# _dashboard_refresh_cache: status tracking
# ---------------------------------------------------------------------------

@test "cache: missing config produces no_config status" {
  CONFIG_FILE=/tmp/definitely-does-not-exist-$$
  _dashboard_refresh_cache
  [ "$DASHBOARD_CACHE_STATUS" = "no_config" ]
  [ -z "$DASHBOARD_ROWS_CACHE" ]
}

@test "cache: empty config produces no_config status" {
  local cfg
  cfg=$(mktemp)
  printf '# only a comment\n\n' > "$cfg"
  CONFIG_FILE="$cfg"
  _dashboard_refresh_cache
  [ "$DASHBOARD_CACHE_STATUS" = "no_config" ]
  rm -f "$cfg"
}

@test "cache: successful fetch produces ok status with rows" {
  local cfg
  cfg=$(mktemp)
  echo "acme/api" > "$cfg"
  CONFIG_FILE="$cfg"
  collect_remote_runners() {
    echo '{"repo":"acme/api","name":"r1","status":"online","busy":false,"labels":[]}'
  }
  _dashboard_refresh_cache
  [ "$DASHBOARD_CACHE_STATUS" = "ok" ]
  [[ "$DASHBOARD_ROWS_CACHE" == *'"name":"r1"'* ]]
  rm -f "$cfg"
}

@test "cache: fetch failure produces fetch_error status" {
  local cfg
  cfg=$(mktemp)
  echo "acme/api" > "$cfg"
  CONFIG_FILE="$cfg"
  collect_remote_runners() {
    echo "boom" >&2
    return 1
  }
  _dashboard_refresh_cache
  [ "$DASHBOARD_CACHE_STATUS" = "fetch_error" ]
  [ -z "$DASHBOARD_ROWS_CACHE" ]
  rm -f "$cfg"
}

@test "cache: refresh updates the timestamp" {
  CONFIG_FILE=/tmp/definitely-does-not-exist-$$
  _dashboard_refresh_cache
  local first="$DASHBOARD_CACHE_AT"
  sleep 1
  _dashboard_refresh_cache
  [ "$DASHBOARD_CACHE_AT" -ge "$first" ]
}
