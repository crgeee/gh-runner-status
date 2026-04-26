#!/usr/bin/env bats
# Stats subcommand: jq aggregation logic. We feed synthetic enriched
# rows directly into jq via inline pipes so the tests don't depend on
# `gh` or any real fleet.

setup() {
  GH_RUNNER_STATUS_NO_MAIN=1 . "${BATS_TEST_DIRNAME}/../gh-runner-status"
}

# The jq aggregation lifted from the `stats` branch of dispatch_subcommand.
# Keep this in sync with the inline jq there.
agg_stats() {
  jq -rs '
    {
      total:    length,
      online:   ([.[] | select(.status == "online")]  | length),
      offline:  ([.[] | select(.status == "offline")] | length),
      err:      ([.[] | select(has("error"))]         | length),
      busy:     ([.[] | select(.busy == true)]        | length),
      idle:     ([.[] | select(.status == "online" and .busy == false)] | length),
      total_cpu: ([.[] | select(.cpu_pct != null) | .cpu_pct] | add // 0),
      total_mem: ([.[] | select(.rss_kb != null)  | .rss_kb]  | add // 0),
      local_count: ([.[] | select(.local == true)] | length),
      repos: ([.[] | .repo] | unique | length),
      oses:  ([.[] | .os // "unknown"] | group_by(.) | map({os: .[0], count: length})),
      top_labels: ([.[] | .labels // [] | .[]] | group_by(.) | map({label: .[0], count: length}) | sort_by(.count) | reverse | .[:5])
    }
  '
}

@test "stats: counts online/offline correctly" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":[],"os":"linux"}
{"repo":"a/b","name":"r2","status":"offline","busy":false,"labels":[],"os":"linux"}
{"repo":"a/c","name":"r3","status":"online","busy":true,"labels":[],"os":"linux"}'
  local out
  out=$(printf '%s\n' "$rows" | agg_stats)
  [ "$(jq -r .online <<<"$out")" = "2" ]
  [ "$(jq -r .offline <<<"$out")" = "1" ]
  [ "$(jq -r .total <<<"$out")" = "3" ]
}

@test "stats: separates busy from idle" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":true,"labels":[]}
{"repo":"a/b","name":"r2","status":"online","busy":false,"labels":[]}
{"repo":"a/b","name":"r3","status":"online","busy":false,"labels":[]}'
  local out
  out=$(printf '%s\n' "$rows" | agg_stats)
  [ "$(jq -r .busy <<<"$out")" = "1" ]
  [ "$(jq -r .idle <<<"$out")" = "2" ]
}

@test "stats: counts errored repo lookups separately from runners" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":[]}
{"repo":"a/c","error":"HTTP 404"}'
  local out
  out=$(printf '%s\n' "$rows" | agg_stats)
  [ "$(jq -r .err <<<"$out")" = "1" ]
  [ "$(jq -r .online <<<"$out")" = "1" ]
}

@test "stats: sums CPU and memory only across local runners" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":[],"local":true,"cpu_pct":5.0,"rss_kb":102400}
{"repo":"a/b","name":"r2","status":"online","busy":false,"labels":[],"local":true,"cpu_pct":10.0,"rss_kb":204800}
{"repo":"a/c","name":"r3","status":"online","busy":false,"labels":[]}'
  local out
  out=$(printf '%s\n' "$rows" | agg_stats)
  [ "$(jq -r .total_cpu <<<"$out")" = "15" ]
  [ "$(jq -r .total_mem <<<"$out")" = "307200" ]
  [ "$(jq -r .local_count <<<"$out")" = "2" ]
}

@test "stats: top_labels ranks by frequency" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":["self-hosted","gpu","linux"]}
{"repo":"a/b","name":"r2","status":"online","busy":false,"labels":["self-hosted","linux"]}
{"repo":"a/c","name":"r3","status":"online","busy":false,"labels":["self-hosted"]}'
  local out top
  out=$(printf '%s\n' "$rows" | agg_stats)
  top=$(jq -r '.top_labels[0].label' <<<"$out")
  [ "$top" = "self-hosted" ]
  [ "$(jq -r '.top_labels[0].count' <<<"$out")" = "3" ]
}

@test "stats: oses grouping" {
  local rows='{"repo":"a/b","name":"r1","status":"online","busy":false,"labels":[],"os":"linux"}
{"repo":"a/b","name":"r2","status":"online","busy":false,"labels":[],"os":"linux"}
{"repo":"a/c","name":"r3","status":"online","busy":false,"labels":[],"os":"macOS"}'
  local out
  out=$(printf '%s\n' "$rows" | agg_stats)
  local linux_count
  linux_count=$(jq -r '.oses[] | select(.os=="linux") | .count' <<<"$out")
  [ "$linux_count" = "2" ]
}

@test "stats: empty input returns zero counts" {
  local out
  out=$(printf '' | agg_stats)
  [ "$(jq -r .total <<<"$out")" = "0" ]
  [ "$(jq -r .online <<<"$out")" = "0" ]
  [ "$(jq -r .offline <<<"$out")" = "0" ]
}
