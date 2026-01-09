# set graveyard for rip/rm-improved
set -gx GRAVEYARD "$HOME/.trash"
mkdir -p $GRAVEYARD
# set default editor
set -gx EDITOR nvim
# nvim for man pages
set -gx MANPAGER "nvim +Man!"
set -gx MANWIDTH 999
# sops stuff
set -gx SOPS_AGE_KEY_FILE "$HOME/.config/sops/age/age-keys.txt"
