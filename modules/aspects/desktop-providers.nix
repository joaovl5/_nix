{inputs, ...}: {
  den.aspects = {
    provider-flatpak.nixos.imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];
    provider-nur.nixos.imports = [inputs.nur.modules.nixos.default];
  };
}
