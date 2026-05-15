{
  hm = {
    inputs,
    pkgs,
    ...
  }: let
    local_packages = import ../../../../packages {inherit pkgs inputs;};
  in {
    home.packages = [
      pkgs.fennel-ls
      local_packages.sane_fnlfmt
    ];
  };
}
