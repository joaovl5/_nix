#!/run/current-system/sw/bin/env -S fish --no-config

source (dirname (status current-filename))/_utils.fish

set emacs_config_dir users/_modules/desktop/apps/editor/emacs/config
set rumdl rumdl

function format_markdown
    set -l files (tracked_files '*.md')
    test (count $files) -eq 0; and return 0

    run_quiet $rumdl fmt \
        --no-cache \
        --silent
end

function format_nix
    set -l files (tracked_files '*.nix')
    test (count $files) -eq 0; and return 0

    run_quiet alejandra \
        --exclude $emacs_config_dir \
        -q -q \
        -- \
        $files
    or return $status

    run_quiet deadnix \
        -_ \
        -L \
        --edit \
        --exclude $emacs_config_dir \
        -- \
        $files
    or return $status

    run_quiet statix fix --ignore $emacs_config_dir -- .
end

function format_fennel
    set -l files (tracked_files '*.fnl')
    test (count $files) -eq 0; and return 0

    run_quiet fnlfmt --fix $files
end

function format_python
    set -l files (tracked_files '*.py' '*.pyi')
    test (count $files) -eq 0; and return 0

    run_quiet ruff format $files
end

function format_web_and_json
    set -l biome_files (tracked_files '*.js' '*.ts' '*.mjs' '*.mts' '*.cjs' '*.cts' '*.jsx' '*.tsx' '*.d.ts' '*.d.cts' '*.d.mts' '*.json' '*.jsonc' '*.css')
    if test (count $biome_files) -gt 0
        run_quiet biome format \
            --write \
            --no-errors-on-unmatched \
            --config-path biome.json \
            --skip-parse-errors \
            --diagnostic-level=warn \
            $biome_files
        or return $status
    end

    set -l json_files (tracked_files '*.json')
    test (count $json_files) -eq 0; and return 0

    run_quiet jsonfmt -w $json_files
end

function format_shells
    set -l fish_files (tracked_files '*.fish')
    if test (count $fish_files) -gt 0
        run_quiet fish_indent --write $fish_files
        or return $status
    end

    set -l sh_files (tracked_files '*.sh' '*.bash' '*.envrc' '*.envrc.*')
    test (count $sh_files) -eq 0; and return 0

    run_quiet shfmt \
        -w \
        -i 2 \
        -s \
        $sh_files
end

function format_toml
    set -l files (tracked_files '*.toml')
    test (count $files) -eq 0; and return 0

    run_quiet taplo format $files
end

function format_yaml
    set -l files (tracked_files '*.yaml' '*.yml')
    test (count $files) -eq 0; and return 0

    run_quiet yamlfmt $files
end

function format_kdl
    set -l files (tracked_files '*.kdl')
    test (count $files) -eq 0; and return 0

    run_quiet kdlfmt format \
        --kdl-version v1 \
        $files
end

function format_sql
    set -l files (tracked_files '*.sql')
    test (count $files) -eq 0; and return 0

    run_quiet sqruff fix $files
end

job_pool_init
job_pool_start format_markdown
job_pool_start format_nix
job_pool_start format_fennel
job_pool_start format_python
job_pool_start format_web_and_json
job_pool_start format_shells
job_pool_start format_toml
job_pool_start format_yaml
job_pool_start format_kdl
job_pool_start format_sql

job_pool_wait
or exit $status

set -l files (tracked_files)
if test (count $files) -gt 0
    run_quiet keep-sorted $files
    or exit $status
end

run_quiet just --fmt
or exit $status
