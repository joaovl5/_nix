#!/run/current-system/sw/bin/fish

set flake_location "$HOME/my_nix" # change flake location later
set mods_path "$flake_location/users/modules"
set xdg_target "$HOME/.config"

ln -sf $mods_path/neovim/config $xdg_target/nvim
ln -sf $mods_path/xplr/config $xdg_target/xplr
