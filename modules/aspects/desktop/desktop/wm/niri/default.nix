_: {
  den.aspects.desktop.homeManager = {
    inputs,
    pkgs,
    ...
  }: {
    imports = [
      inputs.niri.homeModules.niri
    ];

    hybrid-links.links.niri = {
      from = ./config;
      to = "~/.config/niri";
    };

    programs.niri = {
      enable = true;
    };

    services = {
      swaync = {
        enable = true;
      };
      swayidle = {
        enable = true;
        # HACK: Work around swayidle 1.9.0 timeout-only logind bus regression.
        events = {
          "before-sleep" = "true";
        };
        timeouts = [
          {
            timeout = 300;
            command = "niri msg action power-off-monitors";
          }
        ];
      };
    };

    home.packages = with pkgs; [
      xwayland-satellite
    ];
  };
  den.aspects.desktop.nixos = {pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = pkgs.niri-stable;
    };
  };
}
