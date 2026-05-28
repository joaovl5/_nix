_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      stylua
      lua-language-server
    ];
  };
}
