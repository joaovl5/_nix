_: {
  den.aspects.desktop = {
    nixos = _: {
      # services.quassel.enable = true;
    };
    homeManager = {pkgs, ...}: {
      # home.packages = with pkgs; [
      #   quasselClient
      # ];
    };
  };
}
