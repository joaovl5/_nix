{
  lib,
  config,
  ...
} @ args: let
  public_data = import ./public.nix args;
  cfg = config.my.nix;

  ssh_authorized_keys = [
    # all host keys should go here
    # - git_ro_key
    # - servers/etc
    public_data.ssh_key
  ];

  inherit (cfg) user;
in {
  # ssh daemon
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    hostKeys = lib.mkForce [];
    extraConfig = ''
      HostKey /boot/host_key
    '';
  };

  # ssh agent
  programs.ssh = {
    startAgent = true;
    pubkeyAcceptedKeyTypes = lib.mkForce ["ssh-ed25519"];
    hostKeyAlgorithms = lib.mkForce ["ssh-ed25519"];
  };

  users.users."${user}" = {
    openssh.authorizedKeys = ssh_authorized_keys;
  };
}
