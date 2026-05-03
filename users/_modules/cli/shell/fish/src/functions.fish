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

function __yazi_zellij_request_file
    if not set -q ZELLIJ_PANE_ID
        return 1
    end

    set -l runtime_dir /tmp
    if set -q XDG_RUNTIME_DIR
        set runtime_dir $XDG_RUNTIME_DIR
    end

    set -l pane_id (string replace -ra '[^A-Za-z0-9_.-]' '_' -- "$ZELLIJ_PANE_ID")
    echo "$runtime_dir/yazi_zellij_$pane_id.cwd"
end

function __yazi_zellij_consume_request --on-event fish_prompt
    set -l request_file (__yazi_zellij_request_file)
    or return 0

    if not test -f "$request_file"
        return 0
    end

    set -l requested_dir (string trim -- (command cat -- "$request_file"))
    command rm -f -- "$request_file"

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
end

function yazi_zellij_toggle
    set -l request_file (__yazi_zellij_request_file)
    or return 1

    command yazi-zellij-toggle "$request_file" "$PWD"
    __yazi_zellij_consume_request
end

function __yazi_zellij_ctrl_e
    if not set -q ZELLIJ_PANE_ID
        commandline -f end-of-line
        return
    end

    set -l buffer (commandline --current-buffer)
    if test -n "$buffer"
        commandline -f end-of-line
        return
    end

    yazi_zellij_toggle
    commandline -f repaint
end
