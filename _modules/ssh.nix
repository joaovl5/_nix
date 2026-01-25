{lib, ...}: {
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
}
