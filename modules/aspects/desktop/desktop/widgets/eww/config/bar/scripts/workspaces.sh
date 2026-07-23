#!/usr/bin/env bash
set -euo pipefail

detect_compositor() {
  case "${XDG_CURRENT_DESKTOP:-}" in
  *ashrwm*) printf 'ashrwm\n' ;;
  *niri*) printf 'niri\n' ;;
  *)
    if [[ -S "${XDG_RUNTIME_DIR:-}/ashrwm-${WAYLAND_DISPLAY:-}" ]]; then
      printf 'ashrwm\n'
    else
      printf 'niri\n'
    fi
    ;;
  esac
}

emit_niri_workspaces() {
  niri msg --json workspaces 2>/dev/null |
    jq -c '
      map(select(.name != null) | {
        id: .name,
        label: .name,
        display: (if .output == "DP-4" then "primary" else "secondary" end),
        active: .is_active,
        focused: .is_focused,
        urgent: .is_urgent,
        empty: (.active_window_id == null)
      })
      | sort_by(.label)
    ' || printf '[]\n'
}

should_refresh_for_niri_event() {
  case "$1" in
  *'"WorkspacesChanged"'* | *'"WorkspaceActivated"'* | *'"WorkspaceActiveWindowChanged"'* | *'"WorkspaceUrgencyChanged"'* | *'"ConfigLoaded"'*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

listen_niri() {
  while true; do
    emit_niri_workspaces

    if niri msg --json event-stream 2>/dev/null | while IFS= read -r event; do
      if should_refresh_for_niri_event "$event"; then
        emit_niri_workspaces
      fi
    done; then
      sleep 0.2
    else
      emit_niri_workspaces
      sleep 0.2
    fi
  done
}

emit_ashrwm_workspaces() {
  ashrwm-msg workspaces 2>/dev/null |
    jq -c '
      . as $state
      | [range(1; 11) as $tag
         | {
             id: ($tag | tostring),
             label: (["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J"][$tag]),
             display: (if $tag <= 5 then "primary" else "secondary" end),
             active: any($state.outputs[]?; (.tags // []) | index($tag) != null),
             focused: any($state.outputs[]?; ((.focused // false) and ((.tags // []) | index($tag) != null))),
             urgent: false,
             empty: (($state["occupied-tags"] // []) | index($tag) == null)
           }]
    ' || printf '[]\n'
}

listen_ashrwm() {
  local current previous=

  while true; do
    current="$(emit_ashrwm_workspaces)"
    if [[ $current != "$previous" ]]; then
      printf '%s\n' "$current"
      previous="$current"
    fi
    sleep 1
  done
}

focus_ashrwm_tag() {
  local tag="$1" display="$2" output_index state

  [[ $tag =~ ^([1-9]|10)$ ]]
  [[ $display == "primary" || $display == "secondary" ]]

  state="$(ashrwm-msg workspaces)"
  output_index="$(
    jq -er --arg display "$display" '
      .outputs
      | to_entries
      | if $display == "primary"
        then max_by(.value.x)
        else min_by(.value.x)
        end
      | .key
    ' <<<"$state"
  )"

  ashrwm-msg focus-tag "$tag" "$output_index"
}

case "${1:-listen}:$(detect_compositor)" in
listen:niri) listen_niri ;;
listen:ashrwm) listen_ashrwm ;;
focus:niri) niri msg action focus-workspace "$2" ;;
focus:ashrwm) focus_ashrwm_tag "$2" "$3" ;;
*)
  printf 'usage: %s [listen | focus WORKSPACE DISPLAY]\n' "$0" >&2
  exit 2
  ;;
esac
