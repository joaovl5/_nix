function __yazi_zellij_decode_live_cwd
    set -l encoded_dir $argv[1]
    if test -z "$encoded_dir"
        return 1
    end

    printf '%s' "$encoded_dir" | command base64 --decode 2>/dev/null
end

function __yazi_zellij_apply_live_cwd --on-variable __yazi_zellij_live_cwd
    if not set -q __yazi_zellij_live_cwd
        return 0
    end

    set -l payload $__yazi_zellij_live_cwd
    if test (count $payload) -ne 1
        return 0
    end

    set -l parts (string split -m 1 \t -- "$payload[1]")
    if test (count $parts) -ne 2
        return 0
    end

    set -l target_pid $parts[1]
    if not string match -rq '^[0-9]+$' -- "$target_pid"
        return 0
    end

    if test "$target_pid" != "$fish_pid"
        return 0
    end

    set -l requested_dir (__yazi_zellij_decode_live_cwd "$parts[2]")
    or return 0

    if test -z "$requested_dir"
        return 0
    end

    if not test -d "$requested_dir"
        return 0
    end

    if test "$requested_dir" = "$PWD"
        return 0
    end

    cd -- "$requested_dir"
    if status is-interactive
        commandline -f repaint >/dev/null 2>/dev/null
    end
end

function yazi_zellij_toggle
    if not set -q ZELLIJ_PANE_ID
        return 1
    end

    command yazi-zellij-toggle toggle "$PWD" "$fish_pid"
end

function __yazi_zellij_ctrl_e
    if not set -q ZELLIJ_PANE_ID
        commandline -f end-of-line
        return
    end

    set -l buffer (string trim -- (commandline --current-buffer))
    if test -n "$buffer"
        commandline -f end-of-line
        return
    end

    yazi_zellij_toggle
    commandline -f repaint
end

bind ctrl-e __yazi_zellij_ctrl_e
