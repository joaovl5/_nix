{inputs, ...}: {
  den.aspects = {
    provider-disko.nixos.imports = [inputs.disko.nixosModules.default];
    provider-sops.nixos.imports = [inputs.sops-nix.nixosModules.sops];
    provider-nixos-dns.nixos.imports = [inputs.nixos-dns.nixosModules.dns];
  };
}
