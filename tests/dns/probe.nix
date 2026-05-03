_: {
  dns_test,
  pkgs,
  ...
}: let
  inherit (dns_test) probe_ipv4 resolver_ipv4 tld tls_cert;
  ca_cert = pkgs.writeText "dns-test-ca.pem" tls_cert;
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
  ];

  system.stateVersion = "25.11";

  my = {
    nix.hostname = "probe";
    nix.username = "tester";
  };

  virtualisation.vlans = [1];

  networking = {
    interfaces.eth1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = probe_ipv4;
          prefixLength = 24;
        }
      ];
    };
    nameservers = [resolver_ipv4];
    search = [tld];
    firewall.allowPing = true;
  };

  users.users.tester = {
    isNormalUser = true;
    home = "/home/tester";
  };

  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    jq
    openssl
  ];

  environment.etc."dns-test/ca.pem".source = ca_cert;

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [resolver_ipv4];
      Domains = ["~${tld}"];
      FallbackDNS = [];
      MulticastDNS = false;
      DNSSEC = false;
      DNSOverTLS = false;
    };
  };
}
