#!/usr/bin/env bats
# Telegram config parser: must NOT execute arbitrary shell.
# Tests source-load the script so we hit load_telegram_config directly,
# no `gh api` calls, no network.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
  TMPDIR=$(mktemp -d)
  XDG_CONFIG_HOME="$TMPDIR/config"
  mkdir -p "$XDG_CONFIG_HOME/gh-runner-status"
  CFG="$XDG_CONFIG_HOME/gh-runner-status/telegram"
  export XDG_CONFIG_HOME
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
}

teardown() {
  rm -rf "$TMPDIR"
  unset XDG_CONFIG_HOME TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
}

@test "malicious config does NOT execute arbitrary shell" {
  cat > "$CFG" <<EOF
TELEGRAM_BOT_TOKEN=fake
TELEGRAM_CHAT_ID=123
\$(touch $TMPDIR/POWNED)
EOF
  load_telegram_config
  [ ! -f "$TMPDIR/POWNED" ]
}

@test "config keys outside the allowlist are ignored" {
  cat > "$CFG" <<EOF
TELEGRAM_BOT_TOKEN=fake_token
TELEGRAM_CHAT_ID=12345
EVIL_VAR=should_not_appear
EOF
  load_telegram_config
  [ "$TELEGRAM_BOT_TOKEN" = "fake_token" ]
  [ "$TELEGRAM_CHAT_ID" = "12345" ]
  [ -z "${EVIL_VAR:-}" ]
}

@test "comments and blank lines are tolerated" {
  cat > "$CFG" <<EOF
# this is a comment

TELEGRAM_BOT_TOKEN=fake
# trailing comment

TELEGRAM_CHAT_ID=1
EOF
  load_telegram_config
  [ "$TELEGRAM_BOT_TOKEN" = "fake" ]
  [ "$TELEGRAM_CHAT_ID" = "1" ]
}

@test "CRLF line endings are tolerated" {
  printf 'TELEGRAM_BOT_TOKEN=tok\r\nTELEGRAM_CHAT_ID=42\r\n' > "$CFG"
  load_telegram_config
  [ "$TELEGRAM_BOT_TOKEN" = "tok" ]
  [ "$TELEGRAM_CHAT_ID" = "42" ]
}

@test "env vars take precedence over config file" {
  cat > "$CFG" <<EOF
TELEGRAM_BOT_TOKEN=from_file
TELEGRAM_CHAT_ID=from_file
EOF
  TELEGRAM_BOT_TOKEN=from_env load_telegram_config
  # The conditional only loads from file when env is empty, so env should win.
  # We re-export-load: TELEGRAM_BOT_TOKEN was passed inline, so it's set
  # in our environment for that one call. Verify file values for chat_id
  # (which was unset) loaded but bot_token was preserved.
  unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
  TELEGRAM_BOT_TOKEN=preset
  load_telegram_config
  [ "$TELEGRAM_BOT_TOKEN" = "preset" ]
  [ "$TELEGRAM_CHAT_ID" = "from_file" ]
}
