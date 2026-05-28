{inputs, ...}: {
  den.aspects = {
    provider-flatpak.nixos.imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];
    provider-nur.nixos = {lib, ...}: {
      imports = [inputs.nur.modules.nixos.default];

      options.hm_modules = lib.mkOption {
        description = "Home-manager modules for Optnix";
        type = lib.types.listOf lib.types.raw;
        default = [];
      };

      config.hm_modules = [inputs.nur.modules.homeManager.default];
    };
  };
}
