{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  inherit (import ../_lib/modules) extract_imports;
  cfg = config.my.nix;
  local_packages = import ../packages {inherit pkgs inputs;};

  modules = [
    # keep-sorted start
    (import ./_modules/ai)
    (import ./_modules/assets)
    (import ./_modules/cli)
    (import ./_modules/coding)
    (import ./_modules/desktop)
    # keep-sorted end
  ];
  module_imports = extract_imports modules;

  # required for consuming in optnix
  computed_hm_imports =
    [
      inputs.nur.modules.homeManager.default
    ]
    ++ module_imports.hm;
in {
  imports =
    module_imports.nx
    ++ [
      ./_services/post_install
      ./_units
    ]
    ++ (with inputs; [
      nix-flatpak.nixosModules.nix-flatpak
      hm.nixosModules.home-manager
      nur.modules.nixos.default
    ]);

  options.hm_modules = lib.mkOption {
    description = "Home-manager modules for Optnix";
    default = computed_hm_imports;
  };

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
        imports = hm_modules ++ [../home/_modules/hybrid-links];

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

        systemd.user.services.disable-claude-telegram-plugin = {
          Unit = {
            Description = "Disable Claude Telegram plugin when Hermes owns the Telegram bot";
            After = ["default.target"];
          };
          Service = {
            Type = "oneshot";
            ExecStart = let
              script = pkgs.writeShellScript "disable-claude-telegram-plugin" ''
                                set -euo pipefail

                                # The Claude Telegram plugin uses grammY long-polling. grammY's
                                # bot.start() first calls deleteWebhook(), so it steals the bot
                                # from Hermes even when Hermes is in webhook mode. Keep the
                                # plugin token file out of active profiles so Hermes is the
                                # reproducible owner of this bot.
                                for env_file in "$HOME"/.local/share/docker/volumes/frag-profile-*/_data/home/.claude/channels/telegram/.env; do
                                  [ -e "$env_file" ] || continue
                                  backup="$env_file.disabled-by-nix"
                                  if [ ! -e "$backup" ]; then
                                    mv "$env_file" "$backup"
                                  else
                                    rm -f "$env_file"
                                  fi
                                  chmod 0600 "$backup" 2>/dev/null || true
                                done

                                for profile_home in "$HOME"/.local/share/docker/volumes/frag-profile-*/_data/home; do
                                  [ -d "$profile_home" ] || continue

                                  plugin_dir="$profile_home/.claude/plugins/cache/claude-plugins-official/telegram"
                                  disabled_dir="$profile_home/.claude/plugins/cache/claude-plugins-official/telegram.disabled-by-nix"
                                  if [ -d "$plugin_dir" ] && [ ! -e "$disabled_dir" ]; then
                                    mv "$plugin_dir" "$disabled_dir"
                                  elif [ -d "$plugin_dir" ]; then
                                    rm -rf "$plugin_dir"
                                  fi

                                  installed="$profile_home/.claude/plugins/installed_plugins.json"
                                  if [ -f "$installed" ]; then
                                    tmp="$installed.tmp-disable-telegram"
                                    ${pkgs.jq}/bin/jq 'if .plugins then .plugins |= del(."telegram@claude-plugins-official") else . end' "$installed" > "$tmp" \
                                      && mv "$tmp" "$installed" \
                                      || rm -f "$tmp"
                                  fi
                                done

                                for container in $(${pkgs.docker}/bin/docker ps --format '{{.Names}}' | ${pkgs.gawk}/bin/awk '/^frag-/ { print }' || true); do
                                  ${pkgs.docker}/bin/docker exec -i "$container" sh -s <<'FRAG_DISABLE_TELEGRAM' || true
                                    set -eu
                                    profile_home=/state/profile/home

                                    env_file="$profile_home/.claude/channels/telegram/.env"
                                    backup="$env_file.disabled-by-nix"
                                    if [ -f "$env_file" ] && [ ! -e "$backup" ]; then
                                      mv "$env_file" "$backup"
                                    elif [ -f "$env_file" ]; then
                                      rm -f "$env_file"
                                    fi
                                    chmod 0600 "$backup" 2>/dev/null || true

                                    plugin_dir="$profile_home/.claude/plugins/cache/claude-plugins-official/telegram"
                                    disabled_dir="$profile_home/.claude/plugins/cache/claude-plugins-official/telegram.disabled-by-nix"
                                    if [ -d "$plugin_dir" ] && [ ! -e "$disabled_dir" ]; then
                                      mv "$plugin_dir" "$disabled_dir"
                                    elif [ -d "$plugin_dir" ]; then
                                      rm -rf "$plugin_dir"
                                    fi

                                    installed="$profile_home/.claude/plugins/installed_plugins.json"
                                    if [ -f "$installed" ] && command -v jq >/dev/null 2>&1; then
                                      tmp="$installed.tmp-disable-telegram"
                                      jq 'if .plugins then .plugins |= del(."telegram@claude-plugins-official") else . end' "$installed" > "$tmp" \
                                        && mv "$tmp" "$installed" \
                                        || rm -f "$tmp"
                                    fi

                                    ps -eo pid=,args= | awk '/claude-plugins-official\/telegram|\/sw\/bin\/bun server\.ts/ { print $1 }' | while read -r pid; do
                                      [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
                                    done
                FRAG_DISABLE_TELEGRAM
                                done

                                for pid in $(${pkgs.procps}/bin/ps -eo pid=,args= | ${pkgs.gawk}/bin/awk '/claude-plugins-official\/telegram|\/sw\/bin\/bun server\.ts/ { print $1 }' || true); do
                                  kill "$pid" 2>/dev/null || true
                                done
              '';
            in "${script}";
          };
          Install.WantedBy = ["default.target"];
        };

        systemd.user.timers.disable-claude-telegram-plugin = {
          Unit.Description = "Periodically disable Claude Telegram plugin token files";
          Timer = {
            OnBootSec = "30s";
            OnUnitActiveSec = "5min";
            Unit = "disable-claude-telegram-plugin.service";
          };
          Install.WantedBy = ["timers.target"];
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
          local_packages.frag
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
}
