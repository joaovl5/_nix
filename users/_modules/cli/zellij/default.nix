{
  hm = {pkgs, ...}: let
    yazi_zellij_live_cwd = pkgs.writeShellApplication {
      name = "yazi-zellij-live-cwd";
      text = ''
        set -euo pipefail

        fish_bin=${pkgs.fish}/bin/fish
        base64_bin=${pkgs.coreutils}/bin/base64

        if [[ $# -ne 2 ]]; then
          echo "usage: yazi-zellij-live-cwd FISH_PID PATH" >&2
          exit 1
        fi

        fish_pid=$1
        path=$2

        if [[ ! $fish_pid =~ ^[0-9]+$ ]]; then
          echo "yazi-zellij-live-cwd: FISH_PID must be numeric" >&2
          exit 1
        fi

        payload="$fish_pid"$'\t'"$(printf '%s' "$path" | "$base64_bin" -w0)"
        "$fish_bin" -c "set -U __yazi_zellij_live_cwd -- \"\$argv[1]\"" -- "$payload"
      '';
    };

    yazi_zellij_toggle = pkgs.writeShellApplication {
      name = "yazi-zellij-toggle";
      text = ''
        set -euo pipefail

        zellij_bin=${pkgs.zellij}/bin/zellij
        jq_bin=${pkgs.jq}/bin/jq
        env_bin=${pkgs.coreutils}/bin/env
        yazi_bin=${pkgs.yazi}/bin/yazi
        ya_bin=${pkgs.yazi}/bin/ya
        toggle_bin=$0
        live_cwd_bin=${pkgs.lib.getExe yazi_zellij_live_cwd}

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
          if [[ -z ''${ZELLIJ_PANE_ID:-} ]]; then
            fail "ZELLIJ_PANE_ID is not set; run this from inside Zellij"
          fi
        }

        current_tab_id() {
          "$zellij_bin" action current-tab-info --json | "$jq_bin" -er '.tab_id'
        }

        list_panes_json() {
          "$zellij_bin" action list-panes --json --state --tab
        }

        normalize_pane_id() {
          local pane_id=$1

          pane_id=''${pane_id#terminal_}
          pane_id=''${pane_id#plugin_}

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
          list_panes_json | "$jq_bin" -r --arg pane_title "$pane_title" --argjson tab_id "$tab_id" "$jq_filter"
        }

        pane_exists_in_tab() {
          local pane_id
          pane_id=$(normalize_pane_id "$1") || return 1
          local tab_id=$2
          local jq_filter

          jq_filter="any(.[]; .tab_id == \$tab_id and (.is_plugin | not) and .id == \$pane_id)"
          list_panes_json | "$jq_bin" -e --argjson pane_id "$pane_id" --argjson tab_id "$tab_id" "$jq_filter" >/dev/null
        }

        maybe_focus_pane() {
          local pane_id
          pane_id=$(normalize_pane_id "$1") || return 0

          "$zellij_bin" action focus-pane-id "terminal_$pane_id" >/dev/null 2>&1 \
            || "$zellij_bin" action focus-next-pane >/dev/null 2>&1 \
            || true
        }

        maybe_show_floating_panes() {
          local tab_id=$1
          "$zellij_bin" action show-floating-panes --tab-id "$tab_id" >/dev/null 2>&1 || true
        }

        hide_floating_panes() {
          local tab_id=$1
          local status=0

          if "$zellij_bin" action hide-floating-panes --tab-id "$tab_id" >/dev/null 2>&1; then
            return 0
          fi

          status=$?
          if [[ $status -eq 2 ]]; then
            return 0
          fi

          return "$status"
        }

        create_drawer() {
          local pane_title=$1
          local start_cwd=$2
          local fish_pid=$3
          local origin_pane_id=$4
          local client_id=$5

          "$zellij_bin" action new-pane \
            --floating \
            --name "$pane_title" \
            --cwd "$start_cwd" \
            --x 8% \
            --y 56% \
            --width 84% \
            --height 38% \
            -- "$env_bin" \
              "YAZI_ZELLIJ_ORIGIN_FISH_PID=$fish_pid" \
              "YAZI_ZELLIJ_ORIGIN_PANE_ID=$origin_pane_id" \
              "YAZI_ZELLIJ_LIVE_CWD=$live_cwd_bin" \
              "YAZI_ZELLIJ_TOGGLE=$toggle_bin" \
              "$yazi_bin" \
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
            pane_title="__yazi_zellij_drawer_fish_''${fish_pid}__"
            client_id=$fish_pid
            existing_pane_id=$(drawer_pane_id "$pane_title" "$tab_id")

            if [[ -n "$existing_pane_id" ]]; then
              maybe_show_floating_panes "$tab_id"

              if "$ya_bin" emit-to "$client_id" cd "$start_cwd" >/dev/null 2>&1; then
                maybe_focus_pane "$existing_pane_id"
                exit 0
              fi

              if pane_exists_in_tab "$existing_pane_id" "$tab_id"; then
                "$zellij_bin" action close-pane --pane-id "$existing_pane_id" >/dev/null 2>&1 || true
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
            hide_floating_panes "$tab_id"

            if [[ -n ''${YAZI_ZELLIJ_ORIGIN_PANE_ID:-} ]] && pane_exists_in_tab "$YAZI_ZELLIJ_ORIGIN_PANE_ID" "$tab_id"; then
              maybe_focus_pane "$YAZI_ZELLIJ_ORIGIN_PANE_ID"
            fi
            ;;

          *)
            usage
            exit 1
            ;;
        esac
      '';
    };
  in {
    hybrid-links.links.zellij = {
      from = ./config;
      to = "~/.config/zellij";
    };

    home.packages = [
      yazi_zellij_toggle
      yazi_zellij_live_cwd
    ];

    programs.zellij.enable = true;

    xdg.dataFile."zellij/plugins/zjstatus.wasm" = {
      source = "${pkgs.zjstatus}/bin/zjstatus.wasm";
    };
  };
}
