{
  pkgs,
  config,
  inputs,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  environment.shells = [pkgs.bash];
  programs.bash.enable = true;

  users.users.${cfg.username} = {
    isNormalUser = true;
    linger = true; # needed for autostarting pods
    extraGroups = ["wheel" "podman" "libvirt"];
    initialPassword = "12";
    shell = pkgs.fish;
  };

  # allow sudo without password
  security.sudo.extraRules = [
    {
      users = [cfg.username];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  home-manager.users.${cfg.username} = _: {
    home.stateVersion = "23.11";

    home.packages = with pkgs; [
      ## utils
      vim
    ];
  };
}
