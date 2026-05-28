_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      yaml-language-server
      yamlfmt
    ];
  };
}
