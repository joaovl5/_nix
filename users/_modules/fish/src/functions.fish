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

function md --wraps mkdir -d "Create a directory and cd into it"
    command mkdir -p $argv
    if test $status = 0
        switch $argv[(count $argv)]
            case '-*'
            case '*'
                cd $argv[(count $argv)]
                return
        end
    end
end

function !!
    eval sudo $history[1]
end
