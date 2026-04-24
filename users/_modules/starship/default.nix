{
  hm = {lib, ...}: {
    programs.starship = {
      enable = true;
      settings = import ./settings.nix {inherit lib;};
    };
  };
}
