{self, ...} @ inputs: let
  globals = import inputs.globals;
  inherit (globals.dns) tld;

  mk_octodns_config = import ./_octodns_config.nix {inherit inputs;};
in {
  octodns = mk_octodns_config {
    nixos_configurations = self.nixosConfigurations;
    zone_name = "${tld}.";
    zone_providers = ["pihole" "cloudflare"];
    extra_config = globals.dns.extraZoneConfig;
    providers = {
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
    processors.vhost-policy = {
      class = "octodns_vhost_policy.VhostPolicyProcessor";
      inherit (globals.dns) public_vhosts;
      public_ipv4 = globals.hosts.temperance.hostname;
    };
    zone_config.processors = ["vhost-policy"];
  };
}
