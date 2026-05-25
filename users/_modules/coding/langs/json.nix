{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      jsonfmt
    ];
  };
}
