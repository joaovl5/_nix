{mylib, ...}: let
  o = mylib.options;
in
  #
  # Requisites:
  # - declaratively setup pi-hole secrets
  # - use octodns for managing zones
  # - use nixos-dns for zones
  # - manage state in centralized form
  o.module "unit.pihole" (with o; {
    enable = toggle "Enable Pihole" false;
    privacy_level = opt "Pihole statistics privacy level, 0 = full, 3 = only anonymous" t.int 1;
    data_dir = opt "Directory for pihole state data" t.str "${mylib.units.data_dir}/pihole";
    dns = {
      domain = opt "LAN domain" t.str "local";
      interface = opt "Network interface" t.str null;
    };
    web = {
      ports = opt "Web UI ports" (t.listOf t.int) [1111];
    };
  }) {} (opts: (o.when opts.enable {
    services = {
      resolved = {
        extraConfig = ''
          DNSStubListener=no
          MulticastDNS=off
        '';
      };
      pihole-web = {
        enable = true;
        inherit (opts.web) ports;
      };
      pihole-ftl = {
        enable = true;
        openFirewallDNS = true;
        openFirewallDHCP = true;
        openFirewallWebServer = true;
        queryLogDeleter.enable = true;
        useDnsmasqConfig = true;

        stateDirectory = "${opts.data_dir}/state";
        logDirectory = "${opts.data_dir}/logs";
        privacyLevel = opts.privacy_level;

        settings = {
          dhcp = {
            # setup this later
            active = false;
          };
          dns = {
            inherit (opts.dns) domain interface;
            domainNeeded = true;
            expandHosts = true;
            upstreams = ["1.1.1.1" "1.1.1.2"];
            cnameRecords = [];
          };
          ntp = {
            ipv4.active = false;
            ipv6.active = false;
            sync.active = false;
          };
        };

        lists = [
          {
            url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
            type = "block";
            enabled = true;
            description = "Steven Black's HOSTS";
          }
        ];
      };
    };

    # The following silences a benign FTL.log warning:
    # WARNING API: Failed to read /etc/pihole/versions (key: internal_error)
    systemd.tmpfiles.rules = [
      # Type Path Mode User Group Age Argument
      "f /etc/pihole/versions 0644 pihole pihole - -"
    ];
  }))
