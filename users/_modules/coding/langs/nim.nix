{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      nim
      nimlangserver
      nimble
      nph
    ];
  };
}
