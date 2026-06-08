_: {
  den.aspects.guix.nixos = {pkgs, ...}: {
    services.guix = {
      enable = true;
      extraArgs = ["--max-jobs=12"];
      gc = {
        enable = true;
        dates = "weekly";
        extraArgs = ["--optimize" "--delete-generations=1m"];
      };
    };
    environment.systemPackages = [pkgs.guix];
  };
}
