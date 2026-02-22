rec {
  tld = "trll.ing";
  nameservers = [
    # "ns1.invalid.invalid"
    # "ns2.invalid.invalid"
    "aaron.ns.cloudflare.com"
    "bella.ns.cloudflare.com"
  ];

  extraZoneConfig.zones = {
    "${tld}" = {
      "" = {
        ns.data = ["ns1.example.invalid" "ns2.example.invalid"];
        # soa.data = {
        #   mname = builtins.head nameservers;
        #   rname = "null@trll.ing";
        #   serial = 1;
        #   refresh = 7200;
        #   retry = 3600;
        #   ttl = 60;
        #   expire = 1209600;
        # };
      };
    };
  };
}
