# set graveyard for rip/rm-improved
set -Ux GRAVEYARD "$HOME/.trash"
mkdir -p $GRAVEYARD
# set default editor
set -Ux EDITOR nvim
# nvim for man pages
set -Ux MANPAGER "nvim +Man!"
set -Ux MANWIDTH 999
