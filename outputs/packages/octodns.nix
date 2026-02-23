{self, ...} @ inputs: let
  globals = import inputs.globals;
  inherit (globals.dns) tld;
  generate = inputs.nixos-dns.utils.generate inputs.nixpkgs.legacyPackages.x86_64-linux;
in {
  octodns = generate.octodnsConfig {
    dnsConfig = {
      inherit (self) nixosConfigurations;
      extraConfig = globals.dns.extraZoneConfig;
    };
    config.providers = {
      pihole = {
        class = "octodns_pihole.PiholeProvider";
        url = "http://localhost:1111";
        password = "env/PIHOLE_PASSWORD";
        strict_supports = false;
      };
      cloudflare = {
        class = "octodns_cloudflare.CloudflareProvider";
        token = "env/CLOUDFLARE_TOKEN";
        strict_supports = false;
      };
    };
    zones."${tld}." = inputs.nixos-dns.utils.octodns.generateZoneAttrs ["pihole" "cloudflare"];
  };
}
