rec {
  tld = "trll.ing";
  public_vhosts = ["jellyfin"];
  nameservers = [
    "aaron.ns.cloudflare.com"
    "bella.ns.cloudflare.com"
  ];

  extraZoneConfig.zones = {
    "${tld}" = {
      "" = {
        # dummy values for zones file parser to shut up
        # cannot and dont need to use actual nameservers
        # since it's incompatible with cloudflare dns
        ns.data = ["ns1.example.invalid" "ns2.example.invalid"];
      };
    };
  };
}
