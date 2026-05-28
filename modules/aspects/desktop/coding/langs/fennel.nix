_: {
  den.aspects.coding.homeManager = {
    inputs,
    pkgs,
    ...
  }: let
    local_packages = import ../../../../_packages {inherit pkgs inputs;};
  in {
    home.packages = [
      pkgs.fennel-ls
      local_packages.sane_fnlfmt
    ];
  };
}
