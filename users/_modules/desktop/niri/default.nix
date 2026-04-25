{
  nx = _: {
    programs.niri = {
      enable = true;
    };
  };
  hm = {
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
}
