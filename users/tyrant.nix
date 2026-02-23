{
  pkgs,
  config,
  inputs,
  ...
} @ args: let
  cfg = config.my.nix;

  public_data = import ../_modules/public.nix args;
  ssh_authorized_keys = [
    public_data.ssh_key
  ];
in {
  imports = with inputs; [
    hm.nixosModules.home-manager
    ./_units
  ];

  my = {
    "unit.octodns" = {
      enable = true;
    };

    "unit.pihole" = {
      enable = true;
      dns = {
        interface = "enp3s0f1";
      };
    };

    "unit.litellm" = {
      enable = true;
    };

    "unit.nixarr" = {
      enable = true;
    };

    "unit.soularr" = {
      enable = true;
    };

    "unit.fxsync" = {
      enable = true;
    };
  };

  users.users.${cfg.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "libvirt"];
    hashedPasswordFile = config.sops.secrets.password_hash_server.path;
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = ssh_authorized_keys;
  };

  # environment.shells = [pkgs.fish];
  programs.fish.enable = true;

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

  home-manager.users.tyrant = _: {
    home.stateVersion = "23.11";

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;
    };

    home.packages = with pkgs; [
      # deps
      pinentry-curses

      ## utils
      ripgrep
      neovim
      jq
      tmux

      ## monitoring
      glances
      btop
      htop
    ];
  };
}
