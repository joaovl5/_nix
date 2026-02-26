/*
base system for server systems to use
this is not meant to work by itself
*/
{
  pkgs,
  lib,
  config,
  mylib,
  ...
} @ args: let
  public_data = import ../../_modules/public.nix args;
  ssh_authorized_keys = [
    public_data.ssh_key
  ];
  cfg = config.my.nix;

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
          s.mk_secret "${s.dir}/${opts.password.sops_filename}" opts.password.sops_key {};

        users = {
          mutableUsers = false;
          users = {
            root = {
              hashedPasswordFile = s.secret_path root_pw_secret;
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
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = o.def false;
            PermitRootLogin = o.def "no";
          };
        };

        virtualisation = {
          spiceUSBRedirection.enable = o.def true;
          containers.enable = o.def true;
          libvirtd.enable = o.def true;
          docker = {
            enable = o.def false;
            rootless = {
              enable = o.def true;
              setSocketVariable = o.def true;
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
          ripgrep
          fd
          jq
          neovim
          tmux
          curl
          wget
          git
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
