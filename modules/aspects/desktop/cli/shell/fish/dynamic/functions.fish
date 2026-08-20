function !!
    eval sudo $history[1]
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

function jl
    # session name defaults to current directory's name
    set -l session (path basename (pwd))
    # or, if a `.session-name` exists, use its contents

    if test -f .session-name
        set session (string trim < .session-name)
    end

    if set -q $argv[2]; and string length -q -- $argv[2]
        set session $argv[2]
    end
    zellij --new-session-with-layout $argv[1] --session $session
end

function jc
    jl code $session
end
