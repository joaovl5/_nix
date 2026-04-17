{
  hm = {pkgs, ...}: let
    yazi_zellij_toggle = pkgs.writeShellApplication {
      name = "yazi-zellij-toggle";
      text = ''
        set -euo pipefail

        zellij_bin=${pkgs.zellij}/bin/zellij
        jq_bin=${pkgs.jq}/bin/jq
        bash_bin=${pkgs.bash}/bin/bash
        yazi_bin=${pkgs.yazi}/bin/yazi
        rm_bin=${pkgs.coreutils}/bin/rm
        base64_bin=${pkgs.coreutils}/bin/base64
        sleep_bin=${pkgs.coreutils}/bin/sleep

        if [[ $# -ne 2 ]]; then
          echo "usage: yazi-zellij-toggle REQUEST_FILE START_CWD" >&2
          exit 1
        fi

        request_file=$1
        start_cwd=$2

        if [[ -z ''${ZELLIJ_PANE_ID:-} ]]; then
          echo "yazi-zellij-toggle: ZELLIJ_PANE_ID is not set; run this from inside Zellij" >&2
          exit 1
        fi

        pane_title=__yazi_zellij_''${ZELLIJ_PANE_ID//[^[:alnum:]_-]/_}__

        current_tab_id=$("$zellij_bin" action current-tab-info --json | "$jq_bin" -er '.tab_id')
        jq_filter="map(select(.tab_id == \$current_tab_id and (.is_plugin | not) and .title == \$pane_title))[0].id // empty"
        existing_pane_id=$("$zellij_bin" action list-panes --json | "$jq_bin" -r --argjson current_tab_id "$current_tab_id" --arg pane_title "$pane_title" "$jq_filter")

        if [[ -n "$existing_pane_id" ]]; then
          "$rm_bin" -f -- "$request_file"
          "$zellij_bin" action close-pane --pane-id "terminal_$existing_pane_id"
          exit 0
        fi

        "$rm_bin" -f -- "$request_file"
        start_cwd_b64=$(printf '%s' "$start_cwd" | "$base64_bin" -w0)
        request_file_b64=$(printf '%s' "$request_file" | "$base64_bin" -w0)
        pane_command="exec \"$bash_bin\" -lc 'start_cwd=\$(printf %s \"\$1\" | \"$base64_bin\" -d); request_file=\$(printf %s \"\$2\" | \"$base64_bin\" -d); exec \"\$3\" \"\$start_cwd\" \"--cwd-file=\$request_file\"' bash '$start_cwd_b64' '$request_file_b64' '$yazi_bin'"
        new_pane_id=$("$zellij_bin" action new-pane \
          --direction down \
          --name "$pane_title" \
          --cwd "$start_cwd")
        new_pane_id=''${new_pane_id#terminal_}
        new_pane_id=''${new_pane_id#plugin_}
        "$sleep_bin" 0.05
        "$zellij_bin" action paste --pane-id "terminal_$new_pane_id" "$pane_command"
        "$zellij_bin" action send-keys --pane-id "terminal_$new_pane_id" Enter
        wait_filter="any(.[]; .tab_id == \$current_tab_id and (.is_plugin | not) and .id == \$pane_id)"
        while "$zellij_bin" action list-panes --json | "$jq_bin" -e --argjson current_tab_id "$current_tab_id" --argjson pane_id "$new_pane_id" "$wait_filter" >/dev/null; do
          "$sleep_bin" 0.05
        done
      '';
    };
  in {
    hybrid-links.links.zellij = {
      from = ./config;
      to = "~/.config/zellij";
    };

    home.packages = [yazi_zellij_toggle];

    programs.zellij = {
      enable = true;
    };

    xdg.dataFile."zellij/plugins/zjstatus.wasm" = {
      source = "${pkgs.zjstatus}/bin/zjstatus.wasm";
    };
  };
}
