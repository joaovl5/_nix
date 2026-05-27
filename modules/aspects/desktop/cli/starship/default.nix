{lav, ...}: {
  den.aspects.cli.homeManager = {lib, ...}: {
    programs.starship = {
      enable = true;
      settings = lav.cli.starship.settings {inherit lib;};
    };
  };
}
