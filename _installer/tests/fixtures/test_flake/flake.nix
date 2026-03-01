{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    disko,
    ...
  }: {
    nixosConfigurations.test-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./disko.nix
        {
          # minimal config to make evaluation work
          boot.loader.grub.devices = ["/dev/vda"];
          fileSystems."/" = {
            device = "/dev/vda1";
            fsType = "ext4";
          };
          system.stateVersion = "24.11";
        }
      ];
    };
  };
}
