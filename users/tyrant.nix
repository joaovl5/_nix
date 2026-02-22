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
    ./_units/pihole
    ./_units/litellm
    ./_units/nixarr
    ./_units/soularr
    ./_units/traefik
    ./_units/fxsync
  ];

  my = let
    ip_tyrant = "192.168.15.3";
    localhost = "0.0.0.0";
  in {
    dns = {
      hosts = [
        "192.168.15.1 gateway.lan"
        "${ip_tyrant} tyrant.lan"
      ];
      cname_records = [
        "pi.lan,tyrant.lan"
        "litellm.lan,tyrant.lan"
        "jellyfin.lan,tyrant.lan"
        "prowlarr.lan,tyrant.lan"
        "lidarr.lan,tyrant.lan"
        "radarr.lan,tyrant.lan"
        "sonarr.lan,tyrant.lan"
        "bazarr.lan,tyrant.lan"
        "soulseek.lan,tyrant.lan"
        "fxsync.lan,tyrant.lan"
      ];
    };

    "unit.pihole" = {
      enable = true;
      dns = {
        domain = "lan";
        interface = "enp3s0f1";
        host_ip = localhost;
        host_domain = "pi.lan";
      };
    };

    "unit.litellm" = {
      enable = true;
      web = {
        host_ip = ip_tyrant;
      };
      config = {
        model_list = [
          {
            model_name = "gpt-5-mini";
            litellm_params = {
              model = "gpt-5-mini-2025-08-07";
              api_base = "https://api.openai.com";
              api_key = "os.environ/OPENAI_KEY";
            };
          }
        ];
      };
    };

    "unit.nixarr" = {
      enable = true;
      jellyfin.host_ip = localhost;
      prowlarr.host_ip = localhost;
      lidarr.host_ip = localhost;
      radarr.host_ip = localhost;
      sonarr.host_ip = localhost;
      bazarr.host_ip = localhost;
    };

    "unit.soularr" = {
      enable = true;
      slskd.host_ip = localhost;
    };

    "unit.fxsync" = {
      enable = true;
      host = "fxsync.lan";
      host_ip = localhost;
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
