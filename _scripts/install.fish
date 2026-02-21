#!/run/current-system/sw/bin/env fish
#
#
# WORK IN PROGRESS
# WORK IN PROGRESS
# WORK IN PROGRESS
# WORK IN PROGRESS
# WORK IN PROGRESS
# WORK IN PROGRESS

# SET NIX EXP FEATURES (NIX-COMMAND FLAKES)

# - ssh priv key to /root/host_key
# - age priv key to /root/age_sops_key.txt
# - github ssh keypair to /root/.ssh/
# - (?) age key to ??

# git clone https://github.com/joaovl5/_nix /tmp/my_flake
# nix run github:nix-community/disko/latest

# ASSUMING WE'RE ALREADY RUNNING AS ROOT

# Constants
set $TMP_FLAKE_PATH /tmp/my_flake
set $HARDWARE_PATH "$TMP_FLAKE_PATH/hardware"

# User-defined / turn into arguments later
# will include disko cfg+attrs
# must be the same as the subfolder under `/hardware/`
# where a `disko.nix` is expected
set $NIX_HOSTNAME testvm
set $NIX_USERNAME tester # derive from nix cfg later

# Computed
set $HOSTNAME_HARDWARE_PATH = "$HARDWARE_PATH/$NIX_HOSTNAME"
set $DISKO_CONFIG_PATH = "$HOSTNAME_HARDWARE_PATH/disko.nix"

# 1) Run disko
nix run github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    "$DISKO_CONFIG_PATH"

# 2) Prepare to install
mkdir -p
