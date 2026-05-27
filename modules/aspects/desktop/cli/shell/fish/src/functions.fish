function !!
    eval sudo $history[1]
end

function tree --wraps eza --description 'runs eza --tree'
    eza --tree $argv
end

function n.s --wraps nh --description 'runs nh os switch'
    command nh os switch \
        --verbose \
        --show-trace \
        --ask \
        --max-jobs 24 \
        --cores 24 \
        --elevation-program run0
end

function solve_all_conflicts --description 'try to solve all current git conflicts with mergiraf'
    set before (git diff --name-only --diff-filter=U | wc -l)
    for file in (git diff --name-only --diff-filter=U)
        set output (mergiraf solve --keep-backup=false "$file" 2>&1)
        echo "$output"
        if string match -q -- "*Solved all conflicts*" "$output"
            git add "$file"
            echo "now all resolved: $file"
        end
    end
    set after (git diff --name-only --diff-filter=U | wc -l)
    echo "Conflicted files: $before ==> $after"
end

function killp --description 'Kill process that user selects in fzf (from ps aux output)'
    set -l pid (ps aux | fzf -m --header-lines=1 | awk '{print $2}')

    if test -n "$pid"
        echo "Killing processes: $pid"
        kill -9 $pid
    end
end

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
