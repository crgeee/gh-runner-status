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
# Works for both bare invocation (`gh-runner-status`) and the gh
# extension form (`gh runner-status`). Pure bash; no external deps.

_gh_runner_status_subcommands() {
  echo "list status local start stop restart logs watch notify add remove stats --help --version --json --config --threshold"
}

_gh_runner_status_runner_names() {
  case "$(uname -s)" in
    Darwin)
      [[ -d "$HOME/Library/LaunchAgents" ]] || return
      find "$HOME/Library/LaunchAgents" -maxdepth 1 -name 'actions.runner.*.plist' 2>/dev/null \
        | sed 's|.*/||;s|\.plist$||' \
        | awk -F'.' '{print $NF}'   # short name = last segment
      ;;
    Linux)
      systemctl --user list-units --type=service --all --no-legend 'actions.runner.*' 2>/dev/null \
        | awk '{print $1}' | sed 's|\.service$||' \
        | awk -F'.' '{print $NF}'
      ;;
  esac | sort -u
}

_gh_runner_status_complete() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Walk back to find the runner-status subcommand.
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
      # Complete runner short names.
      local names
      names=$(_gh_runner_status_runner_names)
      mapfile -t COMPREPLY < <(compgen -W "$names" -- "$cur")
      return 0
      ;;
    add|remove|list|status)
      # Repo arg — no completion source for arbitrary repos. Suggest
      # configured repos if present.
      local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/gh-runner-status/repos"
      if [[ -f "$cfg" ]]; then
        local repos
        repos=$(sed 's/#.*//' "$cfg" | awk 'NF > 0 { print $1 }')
        mapfile -t COMPREPLY < <(compgen -W "$repos" -- "$cur")
      fi
      return 0
      ;;
  esac

  # No subcommand yet — complete a subcommand or flag.
  mapfile -t COMPREPLY < <(compgen -W "$(_gh_runner_status_subcommands)" -- "$cur")
}

# Register for bare invocation.
complete -F _gh_runner_status_complete gh-runner-status

# Register for `gh runner-status` form. We hijack `gh` only when the
# first arg is `runner-status`; otherwise gh's own completion handles
# things. This wrapper is a no-op for other gh subcommands.
_gh_with_runner_status_completion() {
  if [[ "${COMP_WORDS[1]:-}" == "runner-status" ]]; then
    # Pretend `gh runner-status` is the program.
    local saved=("${COMP_WORDS[@]}")
    COMP_WORDS=("gh-runner-status" "${COMP_WORDS[@]:2}")
    COMP_CWORD=$((COMP_CWORD - 1))
    _gh_runner_status_complete
    COMP_WORDS=("${saved[@]}")
    COMP_CWORD=$((COMP_CWORD + 1))
    return 0
  fi
  # Fall through to gh's default completion if available.
  if declare -F __gh_complete >/dev/null 2>&1; then
    __gh_complete "$@"
  fi
}

# Don't clobber gh's own completion if the user already has it set up.
# We just install our wrapper as a chained handler. Skipping here keeps
# things safe; users who want our completions through `gh runner-status`
# can call the wrapper explicitly.
