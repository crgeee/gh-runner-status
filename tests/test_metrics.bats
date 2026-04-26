#!/usr/bin/env bats
# Metric formatters and host-summary parsers. Source-loaded so we can
# call the helpers directly without spawning the CLI or relying on real
# `uptime`/`vm_stat` output.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
}

# ---------------------------------------------------------------------------
# fmt_rss: kilobytes → "45M" / "1.2G" / "-"
# ---------------------------------------------------------------------------

@test "fmt_rss: empty input returns dash" {
  run fmt_rss ""
  [ "$output" = "-" ]
}

@test "fmt_rss: zero returns dash" {
  run fmt_rss "0"
  [ "$output" = "-" ]
}

@test "fmt_rss: small kb stays as K" {
  run fmt_rss "512"
  [ "$output" = "512K" ]
}

@test "fmt_rss: ~45 MB renders as M" {
  run fmt_rss "46080"   # 45 MB
  [[ "$output" =~ ^4[45]M$ ]]
}

@test "fmt_rss: 1.5 GB renders as G with one decimal" {
  run fmt_rss "1572864"   # 1.5 GiB
  [[ "$output" =~ ^1\.5G$ ]]
}

# ---------------------------------------------------------------------------
# fmt_etime: ps elapsed-time string → "5d 2h" / "2h 30m" / "12m"
# ---------------------------------------------------------------------------

@test "fmt_etime: empty returns dash" {
  run fmt_etime ""
  [ "$output" = "-" ]
}

@test "fmt_etime: minutes only (MM:SS)" {
  run fmt_etime "12:34"
  [ "$output" = "12m" ]
}

@test "fmt_etime: hours+minutes (HH:MM:SS)" {
  run fmt_etime "02:30:00"
  [ "$output" = "2h 30m" ]
}

@test "fmt_etime: days+hours (DD-HH:MM:SS)" {
  run fmt_etime "5-04:15:00"
  [ "$output" = "5d 4h" ]
}

# ---------------------------------------------------------------------------
# host_summary: tolerates env, returns a non-empty string
# ---------------------------------------------------------------------------

@test "host_summary: returns a non-empty string with the three labels" {
  run host_summary
  [ -n "$output" ]
  [[ "$output" == *"uptime:"* ]]
  [[ "$output" == *"load:"* ]]
  [[ "$output" == *"mem:"* ]]
}

# ---------------------------------------------------------------------------
# host_load_avg: returns three numbers space-separated
# ---------------------------------------------------------------------------

@test "host_load_avg: returns three numbers" {
  run host_load_avg
  [ -n "$output" ]
  # three space-separated tokens
  set -- $output
  [ "$#" -eq 3 ]
}
