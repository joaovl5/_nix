#!/run/current-system/sw/bin/env fish

set emacs_vendored_nix **/emacs/config/**.nix
set nix_raw nix --quiet --log-format raw
set rumdl $nix_raw run '.#rumdl' --

function with_files
    set -g files (git ls-files $argv)
    test (count $files) -gt 0
end

if with_files '*.md'
    $rumdl fmt \
        --no-cache \
        --silent
end

if with_files '*.nix'
    alejandra \
        --exclude $emacs_vendored_nix \
        -q -q \
        $files
    deadnix \
        -_ \
        -L \
        --edit \
        --exclude $emacs_vendored_nix \
        $files
    statix fix --ignore $emacs_vendored_nix -- .
end

if with_files '*.fnl'
    fnlfmt --fix $files
end

if with_files '*.py' '*.pyi'
    ruff format $files
end

if with_files '*.js' '*.ts' '*.mjs' '*.mts' '*.cjs' '*.cts' '*.jsx' '*.tsx' '*.d.ts' '*.d.cts' '*.d.mts' '*.json' '*.jsonc' '*.css'
    biome format \
        --write \
        --no-errors-on-unmatched \
        --config-path biome.json \
        --skip-parse-errors \
        --diagnostic-level=warn \
        $files
end

# fish and sh
if with_files '*.fish'
    fish_indent --write $files
end

if with_files '*.sh' '*.bash' '*.envrc' '*.envrc.*'
    shfmt \
        -w \
        -i 2 \
        -s \
        $files
end

if with_files '*.toml'
    taplo format $files
end

if with_files '*.yaml' "*.yml"
    yamlfmt $files
end

if with_files '*.json'
    jsonfmt -w $files
end

if with_files '*.kdl'
    kdlfmt format \
        --kdl-version v1 \
        $files
end

if with_files '*.sql'
    sqruff fix $files
end

if with_files
    keep-sorted $files
end

just --fmt
