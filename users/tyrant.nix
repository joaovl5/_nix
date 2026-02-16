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
    ./_services/traefik
    # ./_services/technitium-dns
    # ./_services/minio
    # ./_services/nextcloud
    # ./_services/syncthing
  ];

  my = let
    ip_tyrant = "192.168.15.3";
  in {
    dns = {
      hosts = [
        "192.168.15.1 gateway.lan"
        "${ip_tyrant} tyrant.lan"
      ];
      cname_records = [
        "pi.lan,tyrant.lan"
        "litellm.lan,tyrant.lan"
      ];
    };

    "unit.pihole" = {
      enable = true;
      dns = {
        domain = "lan";
        interface = "enp3s0f1";
        host_ip = ip_tyrant;
        host_domain = "pihole.lan";
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
            model_name = "*";
            litellm_params = {
              model = "openai/*";
              # read in ExecStart
              api_key = "os.environ/OPENAI_KEY";
            };
          }
        ];
      };
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

      ## monitoring
      glances
      btop
      htop
    ];
  };
}
