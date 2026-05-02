/*
base system for systems to use
this is not meant to work by itself
*/
{
  pkgs,
  lib,
  config,
  mylib,
  globals,
  ...
} @ args: let
  public_data = import ../../_modules/public.nix args;
  inherit (globals) hosts;
  ssh_authorized_keys = [
    public_data.ssh_key
  ];
  cfg = config.my.nix;

  host_cfg = hosts.${cfg.hostname} or {};
  host_ssh_port = host_cfg.ssh_port or 22;

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
in
  o.module "host" (with o; {
    enable = toggle "Enable host options" false;
    title_file = optional "Path to host ASCII-Art title" t.path {};
    disable_privileged_ports = toggle "Disable port privilege for non-root users" false;
    password = {
      sops_filename = opt "File name (from `s.dir`) for sops pw secrets" t.str "password_hashes.yaml";
      sops_key = opt "Key to use for password hash" t.str cfg.hostname;
    };
    home-manager = {
      enable = toggle "Enable home-manager options" true;
      extra_modules = opt "List of extra homeModules to import" (t.listOf t.anything) [];
    };
  }) {
    imports = _: [
      ../_modules/console
      ../_modules/security
      ../_modules/services/ntp.nix
      ../_modules/shell
    ];
  } (opts: (o.when opts.enable (let
    root_pw_secret = "root_pw_${cfg.hostname}";
  in
    o.merge [
      {
        system.stateVersion = "25.11";
        my_system.title = lib.readFile opts.title_file;

        networking = {
          hostName = lib.mkForce cfg.hostname;
        };

        sops.secrets.${root_pw_secret} =
          s.mk_secret "${s.dir}/${opts.password.sops_filename}" opts.password.sops_key {neededForUsers = true;};

        users = {
          mutableUsers = false;
          users = {
            root = {
              hashedPassword = lib.mkForce null;
              hashedPasswordFile = s.secret_path root_pw_secret;
              shell = pkgs.bash;
            };
            "${cfg.username}" = {
              isNormalUser = true;
              extraGroups = ["wheel" "libvirt"];
              hashedPasswordFile = s.secret_path root_pw_secret;
              openssh.authorizedKeys.keys = ssh_authorized_keys;
              shell = lib.mkForce pkgs.fish;
            };
          };
        };

        programs.fish.enable = true;

        services.avahi.enable = o.def true;
        services.openssh = o.def {
          enable = true;
          ports = [host_ssh_port];
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
        };

        virtualisation = o.def {
          spiceUSBRedirection.enable = true;
          containers.enable = true;
          libvirtd.enable = true;
          docker = {
            enable = false;
            rootless = {
              enable = true;
              setSocketVariable = true;
              daemon.settings.dns = [
                "1.1.1.1"
                "1.0.0.1"
              ];
            };
            autoPrune = {
              enable = true;
              dates = "weekly";
            };
          };
        };

        environment.systemPackages = with pkgs; [
          # virtualisation
          docker
          docker-compose

          # utils
          neovim # text editing
          tmux # multiplexer
          ripgrep
          fd
          jq
          curl
          wget
          git
          tmux
          sops
          ## monitoring
          btop
          glances

          # deps
          dconf
        ];
      }
      (o.when opts.disable_privileged_ports {
        boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;
      })
      (o.when opts.home-manager.enable {
        home-manager.users.${cfg.username} = _: {
          home.stateVersion = "23.11";

          imports =
            opts.home-manager.extra_modules;
        };
      })
    ])))
