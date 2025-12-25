{
  inputs,
  lib,
  ...
}: {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    sharedModules = [];
  };
  # needed for home-manager portal/DE configs be linked
  environment.pathsToLink = [/share/applications /share/xdg-desktop-portal];
}
