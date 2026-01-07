{
  inputs,
  lib,
  pkgs,
  system,
  ...
}: {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    sharedModules = [];
    backupCommand = "${pkgs.rm-improved}/bin/rip";
    extraSpecialArgs = {
      inherit inputs;
      inherit system;
    };
    overwriteBackup = true;
  };
  # needed for home-manager portal/DE configs be linked
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
}
