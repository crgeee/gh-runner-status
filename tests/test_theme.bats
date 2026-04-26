#!/usr/bin/env bats
# Coverage for the theme subcommand + settings persistence + env precedence.

setup() {
  TEST_DIR=$(mktemp -d)
  XDG_CONFIG_HOME="$TEST_DIR/config"
  export XDG_CONFIG_HOME
  unset GH_RUNNER_STATUS_THEME
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
  GH_RUNNER_STATUS_NO_MAIN=1 . "$SCRIPT"
}

teardown() {
  rm -rf "$TEST_DIR"
  unset XDG_CONFIG_HOME GH_RUNNER_STATUS_THEME
}

@test "theme: rejects invalid value" {
  run "$SCRIPT" theme bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"theme must be one of"* ]]
}

@test "theme: lists current and available with no args" {
  run "$SCRIPT" theme
  [ "$status" -eq 0 ]
  [[ "$output" == *"current:"* ]]
  [[ "$output" == *"available: dark, light, neon"* ]]
}

@test "theme: persists to settings file" {
  run "$SCRIPT" theme neon
  [ "$status" -eq 0 ]
  [[ "$output" == *"theme set to: neon"* ]]
  local cfg="$XDG_CONFIG_HOME/gh-runner-status/settings"
  [ -f "$cfg" ]
  grep -q "^theme=neon$" "$cfg"
}

@test "theme: next cycles dark -> neon" {
  GH_RUNNER_STATUS_THEME=dark "$SCRIPT" theme next
  local cfg="$XDG_CONFIG_HOME/gh-runner-status/settings"
  grep -q "^theme=neon$" "$cfg"
}

@test "theme: next cycles neon -> light" {
  GH_RUNNER_STATUS_THEME=neon "$SCRIPT" theme next
  grep -q "^theme=light$" "$XDG_CONFIG_HOME/gh-runner-status/settings"
}

@test "theme: next cycles light -> dark" {
  GH_RUNNER_STATUS_THEME=light "$SCRIPT" theme next
  grep -q "^theme=dark$" "$XDG_CONFIG_HOME/gh-runner-status/settings"
}

@test "theme: replaces existing theme line (no duplicate)" {
  "$SCRIPT" theme neon >/dev/null
  "$SCRIPT" theme light >/dev/null
  local cfg="$XDG_CONFIG_HOME/gh-runner-status/settings"
  local count
  count=$(grep -c "^theme=" "$cfg")
  [ "$count" -eq 1 ]
  grep -q "^theme=light$" "$cfg"
}

@test "theme: settings file with invalid value is ignored on load" {
  local cfg="$XDG_CONFIG_HOME/gh-runner-status/settings"
  mkdir -p "$(dirname "$cfg")"
  echo "theme=evilcorp" > "$cfg"
  unset GH_RUNNER_STATUS_THEME
  _load_settings
  [ -z "${GH_RUNNER_STATUS_THEME:-}" ]
}

@test "theme: settings file CRLF tolerated" {
  local cfg="$XDG_CONFIG_HOME/gh-runner-status/settings"
  mkdir -p "$(dirname "$cfg")"
  printf 'theme=light\r\n' > "$cfg"
  unset GH_RUNNER_STATUS_THEME
  _load_settings
  [ "$GH_RUNNER_STATUS_THEME" = "light" ]
}
