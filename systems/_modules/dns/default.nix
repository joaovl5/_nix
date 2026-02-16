{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
in
  o.module "dns" (with o; {
    enable = toggle "Enable DNS presets" true;
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
    hosts =
      opt ''
        List of DNS hosts entries, used by modules like Pi-hole for local dns entries.

        Format is:
        "1.1.1.1 cloudflare"
      ''
      (t.listOf t.str) [];
    cname_records =
      opt ''
        List of CNAME records, used by modules like Pi-hole for local dns entries.

        Format is:
        "service.lan,svc.lan"
      ''
      (t.listOf t.str) [];
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
  }))
