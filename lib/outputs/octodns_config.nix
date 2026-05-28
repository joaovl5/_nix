{inputs}: {
  nixos_configurations,
  zone_name,
  zone_providers,
  extra_config ? {},
  providers ? {},
  processors ? {},
  zone_config ? {},
}: let
  inherit (inputs.nixpkgs) lib;
  generate = inputs.nixos-dns.utils.generate inputs.nixpkgs.legacyPackages.x86_64-linux;
in
  generate.octodnsConfig {
    dnsConfig = {
      nixosConfigurations = nixos_configurations;
      extraConfig = extra_config;
    };
    config =
      lib.optionalAttrs (providers != {}) {inherit providers;}
      // lib.optionalAttrs (processors != {}) {inherit processors;};
    zones.${zone_name} = inputs.nixos-dns.utils.octodns.generateZoneAttrs zone_providers // zone_config;
  }
