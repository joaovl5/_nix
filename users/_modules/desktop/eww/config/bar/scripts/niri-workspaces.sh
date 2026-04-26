#!/usr/bin/env bash
set -euo pipefail

emit_workspaces() {
  local workspaces

  if workspaces="$(niri msg --json workspaces 2>/dev/null)"; then
    printf '%s\n' "$workspaces"
  else
    printf '[]\n'
  fi
}

should_refresh_for_event() {
  case "$1" in
    *'"WorkspacesChanged"'* | *'"WorkspaceActivated"'* | *'"WorkspaceActiveWindowChanged"'* | *'"WorkspaceUrgencyChanged"'* | *'"ConfigLoaded"'*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while true; do
  emit_workspaces

  if niri msg --json event-stream 2>/dev/null | while IFS= read -r event; do
    if should_refresh_for_event "$event"; then
      emit_workspaces
    fi
  done; then
    sleep 0.2
  else
    emit_workspaces
    sleep 0.2
  fi
done
