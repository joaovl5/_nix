#!/run/current-system/sw/bin/env fish

# Updates the fuck of the computer

nh os switch \
    --elevation-program run0 \
    --diff always \
    --refresh \
    --repair \
    --verbose \
    --show-trace
tldr --update
nvim --headless "+Lazy! sync" +qa
emacs \
    --batch \
    -l ~/.config/emacs/init.el \
    --eval '(my/straight-update-all)'
