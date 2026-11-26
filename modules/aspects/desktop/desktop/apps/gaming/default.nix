_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    # programs.lutris = {
    #   enable = false; # fix later ldap thing
    # };
    programs.mangohud = {
      enable = true;
    };
    home.packages = with pkgs; [
      glfw
      wineWow64Packages.full
      winetricks
      me3
    ];
  };
  den.aspects.desktop.nixos = {
    pkgs,
    config,
    ...
  }: {
    services.udev.extraRules = ''
      SUBSYSTEM=="input", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="201b", MODE="0660", GROUP="input"
    '';
    environment.systemPackages = with pkgs; [
      steamcmd
      protonup-qt
    ];
    programs = {
      gamemode.enable = true;
      gamemode.settings = {
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
      # lutris = {
      #   enable = true;
      #   steamPackage = config.programs.steam.package;
      # };
      gamescope = {
        enable = true;
        capSysNice = true;
        enableWsi = true;
        package = pkgs.gamescope;
      };
      steam = {
        enable = true;
        extest.enable = true;
        protontricks.enable = true;
        remotePlay.openFirewall = false;
        dedicatedServer.openFirewall = false;
        localNetworkGameTransfers.openFirewall = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
          nur.repos.quriosity.proton-cachyos
          nur.repos.quriosity.proton-cachyos-v3
          nur.repos.quriosity.proton-wineland
          nur.repos.quriosity.proton-wineland-v3
        ];
        package = pkgs.steam.override {
          extraLibraries = pkgs':
            with pkgs'; [
              SDL2
              dxvk
            ];
          extraPkgs = pkgs': (with pkgs'; [
            libXcursor
            libXi
            libXinerama
            libXScrnSaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib # Provides libstdc++.so.6
            libkrb5
            keyutils
            # Add other libraries as needed
          ]);
        };
        gamescopeSession = {
          enable = true;
          env = {
            WLR_RENDERER = "vulkan";
            DXVK_HDR = "1";
            ENABLE_GAMESCOPE_WSI = "1";
            WINE_FULLSCREEN_FSR = "1";
            # Games allegedly prefer X11
            SDL_VIDEODRIVER = "x11";
          };
          args = [
            "--xwayland-count 2"
            "--expose-wayland"

            "-e" # Enable steam integration
            "--steam"

            "--adaptive-sync"
            "--hdr-enabled"
            "--hdr-itm-enable"

            "--prefer-output DP-4"
            "--output-width 3840"
            "--output-height 2160"
            "-r 240"
            "--prefer-vk-device" # lspci -nn | grep VGA
            "10de:2208" # Dedicated
            # 1002:1681 # Integrated
          ];
          steamArgs = [
            "-tenfoot"
            "-pipewire-dmabuf"
          ];
        };
      };
    };
  };
}
