{den, ...}: {
  den.aspects.user-lav = {
    includes = [den.aspects.user-lav-post-install];
    nixos = {
      pkgs,
      config,
      inputs,
      ...
    }: let
      cfg = config.my.nix;
    in {
      config = {
        users.groups.uinput = {};
        users.users.${cfg.username} = {
          # hashedPasswordFile = s.secret_path "password_hash";

          isNormalUser = true;
          shell = pkgs.fish;
          extraGroups = [
            "wheel"
            "libvirt"
            "input"
          ];
        };

        home-manager.users.${cfg.username} = let
          inherit (config) hm_modules;
        in
          _: {
            imports = hm_modules ++ [../../../../home/_modules/hybrid-links];

            hybrid-links.source_root = inputs.self.outPath;
            hybrid-links.source_path = cfg.repo_location;

            home.stateVersion = "23.11";

            ## cli tools
            my.syncthing = {
              enable = true;
            };

            ### gpg
            services = {
              gpg-agent = {
                enable = true;
                enableSshSupport = true;
              };
            };

            # etc
            home.packages = with pkgs; [
              # terminal
              ## emulator
              ghostty
              alacritty # backup
              ## multiplexer
              ## tui
              systemctl-tui
              gdu # ncdu alternative (MUCH faster on SSDs)

              # gui
              waylock ## locker
              ## launcher
              fuzzel # backup
              ## docs
              # libreoffice
              ## file manager
              thunar
              ## settings
              nwg-look
              pwvucontrol

              ## vms
              virt-manager

              ## etc move later

              zrythm
              ardour
              wireguard-tools
              copier
              jq
              bit-logo
              python314Packages.huggingface-hub
              cursor-cli
              azure-cli
              (openvpn.override {
                openssl = openssl_legacy;
              })
              rustdesk

              # dependencies
              # keep-sorted start
              bc
              cliphist
              go-grip
              libnotify
              perl
              pinentry-curses
              playerctl
              rsync
              runapp
              unzip
              wl-clipboard # wl-paste/...
              xclip
              # keep-sorted end
            ];
          };
      };
    };
  };
}
