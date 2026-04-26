#!/usr/bin/env bats
# Telegram config parser: must NOT execute arbitrary shell.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../gh-runner-status"
  TMPDIR=$(mktemp -d)
  XDG_CONFIG_HOME="$TMPDIR/config"
  mkdir -p "$XDG_CONFIG_HOME/gh-runner-status"
  CFG="$XDG_CONFIG_HOME/gh-runner-status/telegram"
  REPOS="$XDG_CONFIG_HOME/gh-runner-status/repos"
  echo "owner/repo" > "$REPOS"
  export XDG_CONFIG_HOME
  export TELEGRAM_BOT_TOKEN=""
  export TELEGRAM_CHAT_ID=""
}

teardown() {
  rm -rf "$TMPDIR"
  unset XDG_CONFIG_HOME TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
}

@test "malicious config does NOT execute arbitrary shell" {
  # If load_telegram_config used `source`, this would create a sentinel
  # file. We verify it does not.
  cat > "$CFG" <<EOF
TELEGRAM_BOT_TOKEN=fake
TELEGRAM_CHAT_ID=123
\$(touch $TMPDIR/POWNED)
EOF
  # Run notify so load_telegram_config fires. The notify path needs gh
  # auth to actually send, but we only care about config-parsing here.
  run "$SCRIPT" notify owner/repo --threshold 99
  [ ! -f "$TMPDIR/POWNED" ]
}

@test "config keys outside the allowlist are ignored" {
  cat > "$CFG" <<EOF
TELEGRAM_BOT_TOKEN=fake_token
TELEGRAM_CHAT_ID=12345
EVIL_VAR=should_not_appear
EOF
  # Hard to assert without running notify against a real bot; instead
  # verify the parser at least doesn't crash and doesn't surface
  # EVIL_VAR in any error message.
  run "$SCRIPT" notify owner/repo --threshold 99
  [[ "$output" != *"should_not_appear"* ]]
}

@test "comments and blank lines are tolerated" {
  cat > "$CFG" <<EOF
# this is a comment

TELEGRAM_BOT_TOKEN=fake
# trailing comment

TELEGRAM_CHAT_ID=1
EOF
  run "$SCRIPT" notify owner/repo --threshold 99
  # Should not error out on parser; may error later on telegram_send
  # because the token is fake. Check it didn't crash on parse.
  [[ "$output" != *"unbound variable"* ]]
  [[ "$output" != *"syntax error"* ]]
}
