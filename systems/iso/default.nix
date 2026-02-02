{
  pkgs,
  lib,
  modulesPath,
  ...
} @ args: let
  public_data = import ../../_modules/public.nix args;

  ssh_port = 2222;
  ssh_authorized_keys = [
    # all host keys should go here
    # - git_ro_key
    # - servers/etc
    public_data.ssh_key
  ];

  user = "iso";
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../plankton
    ../_modules/console
    {my_system.title = lib.readFile ./assets/title.txt;}
  ];

  # faster build time
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  # enable SSH in the boot process
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce ["multi-user.target"];

  programs = {
    fish = {
      enable = true;
    };
  };

  services.openssh = {
    ports = lib.mkForce ssh_port;
    passwordAuthentication = false;
    permitRootLogin = false;
  };

  users.users."${user}" = {
    openssh.authorizedKeys = ssh_authorized_keys;
  };

  environment.systemPackages = with pkgs; [
    neovim
  ];
}
