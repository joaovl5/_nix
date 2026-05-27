#!/run/current-system/sw/bin/env -S fish --no-config

source (dirname (status current-filename))/_utils.fish

set emacs_config_dir users/_modules/desktop/apps/editor/emacs/config
set nix_raw nix --quiet --log-format raw

function check_statix
    run_quiet statix check \
        -o errfmt \
        -i $emacs_config_dir
end

function check_markdown
    run_quiet rumdl check \
        --no-cache \
        --silent \
        --fail-on warning \
        --output-format concise
end

function check_python_lint
    run_quiet ruff --quiet check \
        --no-cache
end

function check_python_types
    run_quiet basedpyright --warnings
end

function check_nix_outputs
    run_quiet $nix_raw build --no-link --file . checks.x86_64-linux
end

job_pool_init
job_pool_start check_statix
job_pool_start check_markdown
job_pool_start check_python_lint
job_pool_start check_python_types
job_pool_start check_nix_outputs

job_pool_wait
or exit $status
