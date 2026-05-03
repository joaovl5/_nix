set -euo pipefail

# Will be replaced at activation-time by Nix with the actual path to the live-cwd script.
live_cwd_bin="@live_cwd_bin@"
toggle_bin=$0

usage() {
  cat >&2 <<'EOF'
usage:
  yazi-zellij-toggle toggle START_CWD FISH_PID
  yazi-zellij-toggle hide
EOF
}

fail() {
  echo "yazi-zellij-toggle: $*" >&2
  exit 1
}

require_zellij_pane() {
  if [[ -z ${ZELLIJ_PANE_ID:-} ]]; then
    fail "ZELLIJ_PANE_ID is not set; run this from inside Zellij"
  fi
}

current_tab_id() {
  zellij action current-tab-info --json | jq -er '.tab_id'
}

list_panes_json() {
  zellij action list-panes --json --state --tab
}

normalize_pane_id() {
  local pane_id=$1

  pane_id=${pane_id#terminal_}
  pane_id=${pane_id#plugin_}

  if [[ ! $pane_id =~ ^[0-9]+$ ]]; then
    return 1
  fi

  printf '%s\n' "$pane_id"
}

drawer_pane_id() {
  local pane_title=$1
  local tab_id=$2
  local jq_filter

  jq_filter="map(select(.tab_id == \$tab_id and (.is_plugin | not) and .is_floating and .title == \$pane_title))[0].id // empty"
  list_panes_json | jq -r --arg pane_title "$pane_title" --argjson tab_id "$tab_id" "$jq_filter"
}

pane_exists_in_tab() {
  local pane_id
  pane_id=$(normalize_pane_id "$1") || return 1
  local tab_id=$2
  local jq_filter

  jq_filter="any(.[]; .tab_id == \$tab_id and (.is_plugin | not) and .id == \$pane_id)"
  list_panes_json | jq -e --argjson pane_id "$pane_id" --argjson tab_id "$tab_id" "$jq_filter" >/dev/null
}

maybe_focus_pane() {
  local pane_id
  pane_id=$(normalize_pane_id "$1") || return 0

  zellij action focus-pane-id "terminal_$pane_id" >/dev/null 2>&1 \
    || zellij action focus-next-pane >/dev/null 2>&1 \
    || true
}

maybe_show_floating_panes() {
  local tab_id=$1
  zellij action show-floating-panes --tab-id "$tab_id" >/dev/null 2>&1 || true
}

hide_floating_panes() {
  local tab_id=$1
  local status=0

  if zellij action hide-floating-panes --tab-id "$tab_id" >/dev/null 2>&1; then
    return 0
  fi

  status=$?
  if [[ $status -eq 2 ]]; then
    return 0
  fi

  return "$status"
}

export_live_cwd_from_pane() {
  local fish_pid=${YAZI_ZELLIJ_ORIGIN_FISH_PID:-}

  if [[ ! $fish_pid =~ ^[0-9]+$ ]]; then
    return 0
  fi

  "$live_cwd_bin" "$fish_pid" "$PWD" >/dev/null 2>&1 || true
}

create_drawer() {
  local pane_title=$1
  local start_cwd=$2
  local fish_pid=$3
  local origin_pane_id=$4
  local client_id=$5

  zellij action new-pane \
    --floating \
    --name "$pane_title" \
    --cwd "$start_cwd" \
    --x 8% \
    --y 56% \
    --width 84% \
    --height 38% \
    --close-on-exit \
    -- env \
      "YAZI_ZELLIJ_ORIGIN_FISH_PID=$fish_pid" \
      "YAZI_ZELLIJ_ORIGIN_PANE_ID=$origin_pane_id" \
      "YAZI_ZELLIJ_LIVE_CWD=$live_cwd_bin" \
      "YAZI_ZELLIJ_TOGGLE=$toggle_bin" \
      yazi \
      "--client-id=$client_id" \
      "$start_cwd" >/dev/null
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

require_zellij_pane

case "$1" in
  toggle)
    if [[ $# -ne 3 ]]; then
      usage
      exit 1
    fi

    start_cwd=$2
    fish_pid=$3
    origin_pane_id=$(normalize_pane_id "$ZELLIJ_PANE_ID") || fail "ZELLIJ_PANE_ID must be a terminal pane id"

    if [[ ! $fish_pid =~ ^[0-9]+$ ]]; then
      fail "FISH_PID must be numeric"
    fi

    tab_id=$(current_tab_id)
    pane_title="__yazi_zellij_drawer_fish_${fish_pid}__"
    client_id=$fish_pid
    existing_pane_id=$(drawer_pane_id "$pane_title" "$tab_id")

    if [[ -n $existing_pane_id ]]; then
      maybe_show_floating_panes "$tab_id"

      if ya emit-to "$client_id" cd "$start_cwd" >/dev/null 2>&1; then
        maybe_focus_pane "$existing_pane_id"
        exit 0
      fi

      if pane_exists_in_tab "$existing_pane_id" "$tab_id"; then
        zellij action close-pane --pane-id "$existing_pane_id" >/dev/null 2>&1 || true
      fi
    fi

    create_drawer "$pane_title" "$start_cwd" "$fish_pid" "$origin_pane_id" "$client_id"
    ;;

  hide)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi

    tab_id=$(current_tab_id)
    export_live_cwd_from_pane
    hide_floating_panes "$tab_id"

    if [[ -n ${YAZI_ZELLIJ_ORIGIN_PANE_ID:-} ]] && pane_exists_in_tab "$YAZI_ZELLIJ_ORIGIN_PANE_ID" "$tab_id"; then
      maybe_focus_pane "$YAZI_ZELLIJ_ORIGIN_PANE_ID"
    fi
    ;;

  *)
    usage
    exit 1
    ;;
esac
