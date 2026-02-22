{
  mylib,
  config,
  inputs,
  lib,
  ...
}: let
  globals = import inputs.globals;

  my = mylib.use config;
  o = my.options;

  vhosts = config.my.vhosts or {};
  inherit (config.my.dns) tld;
in
  o.module "dns" (with o; {
    enable = toggle "Enable DNS presets" true;
    tld = opt "Top-level domain" t.str globals.dns.tld;
    tld_nameservers = opt "Nameservers for TLD" (t.listOf t.str) globals.dns.nameservers;
    main_dns = opt "List of DNS servers" (t.listOf t.str) [
      "192.168.15.13"
    ];
    fallback_dns = opt "List of fallback DNS servers" (t.listOf t.str) [
      # quad9
      "2620:fe::fe"
      "2620:fe::9"
      "9.9.9.9"
      "149.112.112.112"
    ];
    use_dnssec = toggle "Whether to use DNSSEC" false;
    use_tls = toggle "Whether to use TLS" false;
  }) {}
  (opts: (o.when opts.enable {
    networking.nameservers = opts.main_dns;
    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNS = opts.main_dns;
        FallbackDNS = opts.fallback_dns;
        DNSSEC = opts.use_dnssec;
        DNSOverTLS = opts.use_tls;
      };
    };

    # nixos-dns: base domain and auto-generated subdomains from vhosts
    networking.domains = {
      enable = true;
      baseDomains.${tld} = {
        a.data = builtins.head opts.main_dns;
        # ns.data = opts.tld_nameservers;
      };

      subDomains =
        lib.mapAttrs'
        (_name: vhost: {
          name = "${vhost.target}.${tld}";
          value = {};
        })
        vhosts;
    };
  }))
