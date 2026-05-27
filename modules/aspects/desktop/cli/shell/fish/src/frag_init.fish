set -l __frag_init_dir (status dirname)
source $__frag_init_dir/container_safe_vars.fish
source $__frag_init_dir/container_safe_functions.fish
set -e __frag_init_dir
if command -q starship
    starship init fish | source
end
