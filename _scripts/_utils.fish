function tracked_files
    git ls-files $argv
end

function run_quiet
    set -l output_file (mktemp)

    command $argv >$output_file 2>&1
    set -l status_code $status

    if test $status_code -ne 0
        if test -s $output_file
            command cat $output_file >&2
        end
        command rm -f $output_file
        return $status_code
    end

    command rm -f $output_file
end

function job_pool_init
    set -g fish_job_pool_pids
    set -g fish_job_pool_status_files
end

function job_pool_start
    set -l status_file (mktemp)
    set -a fish_job_pool_status_files $status_file

    begin
        $argv
        echo $status >$status_file
    end &
    set -a fish_job_pool_pids $last_pid
end

function job_pool_wait
    set -l status_code 0

    for pid in $fish_job_pool_pids
        wait $pid
    end

    for status_file in $fish_job_pool_status_files
        set -l job_status 1

        if test -e $status_file
            read job_status <$status_file
            command rm -f $status_file
        end

        if test "$job_status" -ne 0
            set status_code $job_status
        end
    end

    set -e fish_job_pool_pids
    set -e fish_job_pool_status_files

    if test $status_code -ne 0
        return $status_code
    end
end
