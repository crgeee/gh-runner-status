# Bash completion for `gh runner-status`.
#
# Source this file from your shell init to enable tab-completion at
# the shell prompt:
#
#   echo 'source ~/.local/share/gh/extensions/gh-runner-status/completions/gh-runner-status.bash' >> ~/.bashrc
#
# Provides:
# - subcommand completion (list, local, start, stop, restart, logs, ...)
# - runner short-name completion for start/stop/restart/logs (reads
#   installed LaunchAgents on macOS / systemd units on Linux)
# - flag completion (--help, --json, --config, ...)
#
# Works for both `gh-runner-status` (direct binary) and `gh runner-status`
# (the gh-extension form). Pure bash, compatible with bash 3.2 (macOS
# default — no mapfile/readarray usage).

_gh_runner_status_subcommands() {
  echo "list status local start stop restart logs watch notify add remove stats --help --version --json --config --threshold"
}

_gh_runner_status_runner_names() {
  case "$(uname -s)" in
    Darwin)
      [[ -d "$HOME/Library/LaunchAgents" ]] || return
      find "$HOME/Library/LaunchAgents" -maxdepth 1 -name 'actions.runner.*.plist' 2>/dev/null \
        | sed 's|.*/||;s|\.plist$||' \
        | awk -F'.' '{print $NF}'
      ;;
    Linux)
      # Mirror list_local_runners: query both user and system services
      # so completion matches what the script actually controls. `|| true`
      # absorbs missing-D-Bus / non-systemd hosts.
      {
        systemctl --user list-units --type=service --all --no-legend 'actions.runner.*' 2>/dev/null || true
        systemctl list-units --type=service --all --no-legend 'actions.runner.*' 2>/dev/null || true
      } | awk '{print $1}' \
        | sed 's|\.service$||' \
        | awk -F'.' 'NF{print $NF}'
      ;;
  esac | sort -u
}

_gh_runner_status_complete() {
  COMPREPLY=()
  local cur="${COMP_WORDS[COMP_CWORD]}"

  # Walk back to find the runner-status subcommand among prior words.
  local subcmd="" i
  for (( i = 1; i < COMP_CWORD; i++ )); do
    case "${COMP_WORDS[i]}" in
      list|status|local|start|stop|restart|logs|watch|notify|add|remove|stats)
        subcmd="${COMP_WORDS[i]}"
        break
        ;;
    esac
  done

  case "$subcmd" in
    start|stop|restart|logs)
      local names
      names=$(_gh_runner_status_runner_names)
      # bash-3.2-safe: array-builtin compgen output via word-splitting.
      # COMPREPLY expects an array; relying on default IFS for newline.
      # shellcheck disable=SC2207
      COMPREPLY=( $(compgen -W "$names" -- "$cur") )
      return 0
      ;;
    add|remove|list|status)
      local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/gh-runner-status/repos"
      if [[ -f "$cfg" ]]; then
        local repos
        repos=$(sed 's/#.*//' "$cfg" | awk 'NF > 0 { print $1 }')
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$repos" -- "$cur") )
      fi
      return 0
      ;;
  esac

  # No subcommand yet — complete a subcommand or flag.
  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "$(_gh_runner_status_subcommands)" -- "$cur") )
}

# Direct invocation: `gh-runner-status <TAB>`.
complete -F _gh_runner_status_complete gh-runner-status

# `gh runner-status <TAB>` form. We register a small wrapper on `gh`
# that delegates to ours when the first arg is `runner-status`,
# otherwise no-ops so gh's own completion (if loaded later) takes
# over.
_gh_runner_status_gh_wrapper() {
  if [[ "${COMP_WORDS[1]:-}" == "runner-status" ]]; then
    # Re-frame as if `gh-runner-status` is the program: drop `gh` and
    # `runner-status` from the front of COMP_WORDS, decrement CWORD.
    local saved_words=( "${COMP_WORDS[@]}" )
    local saved_cword=$COMP_CWORD
    COMP_WORDS=( "gh-runner-status" "${COMP_WORDS[@]:2}" )
    COMP_CWORD=$(( COMP_CWORD - 1 ))
    _gh_runner_status_complete
    COMP_WORDS=( "${saved_words[@]}" )
    COMP_CWORD=$saved_cword
    return 0
  fi
  # Not our subcommand — produce no completion. Users with gh's own
  # completion installed will see those completions through the normal
  # `complete -p gh` registration; if our wrapper was registered last,
  # the user can re-source gh's own completion to chain it.
  return 0
}

complete -F _gh_runner_status_gh_wrapper gh
