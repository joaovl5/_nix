{
  mylib,
  config,
  pkgs,
  inputs,
  ...
}: let
  globals = import inputs.globals;

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;

  inherit (globals.dns) tld;
  dns_cfg = config.my.dns;
in
  o.module "unit.pihole" (with o; {
    enable = toggle "Enable Pihole" false;
    privacy_level = opt "Pihole statistics privacy level, 0 = full, 3 = only anonymous" t.int 1;
    data_dir = opt "Directory for pihole state data" t.str "${u.data_dir}/pihole";
    endpoint = u.endpoint {
      port = 1111;
      target = "pihole";
    };
    dns = {
      interface = opt "Network interface" t.str null;
      extra_hosts = opt "List of extra hosts for DNS, aside from those managed by octodns" (t.listOf t.str) [];
      upstreams = opt "List of upstream DNS servers" (t.listOf t.str) dns_cfg.fallback_dns;
    };
  }) {} (opts: (o.when opts.enable (let
    pkg = pkgs.pihole-ftl;
    user = "pihole";
    group = "pihole";

    source_log_dir = "/var/log/pihole";
    source_state_dir = "/var/lib/pihole";
    target_log_link = "${opts.data_dir}/logs";
    target_state_link = "${opts.data_dir}/lib";

    pihole_ftl = config.systemd.services.pihole-ftl.serviceConfig;
  in {
    my.vhosts.pihole = {
      inherit (opts.endpoint) target sources;
    };

    sops.secrets = {
      "pihole_api_key" = s.mk_secret "${s.dir}/dns.yaml" "pihole-api-key" {
        owner = user;
        inherit group;
      };
    };

    system.activationScripts.ensure_data_directory_pihole = ''
      echo "[!] Ensuring Pihole directories and symlinks"
      mkdir -v -p ${opts.data_dir}
      ln -sfn ${source_log_dir} ${target_log_link}
      ln -sfn ${source_state_dir} ${target_state_link}
    '';

    systemd.services.pihole-pwhash = {
      description = "Initialize Pi-hole API password hash";
      requiredBy = ["pihole-ftl.service"];
      before = ["pihole-ftl.service"];
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = group;
        ExecStart = pkgs.writeShellScript "exec_pihole_pwhash" ''
          ${pkg}/bin/pihole-FTL --config webserver.api.pwhash $(cat ${s.secret_path "pihole_api_key"})
        '';

        inherit (pihole_ftl) AmbientCapabilities;
      };
    };

    services = {
      resolved.settings.Resolve = {
        DNSStubListener = "no";
        MulticastDNS = "off";
      };
      pihole-web = {
        enable = true;
        ports = [opts.endpoint.port];
      };
      pihole-ftl = {
        enable = true;
        inherit user group;
        package = pkg;

        openFirewallDNS = true;
        openFirewallDHCP = true;
        openFirewallWebserver = true;
        queryLogDeleter.enable = true;
        useDnsmasqConfig = true;

        stateDirectory = source_state_dir;
        logDirectory = source_log_dir;
        privacyLevel = opts.privacy_level;

        settings = {
          misc.readOnly = false; # necessary for pwhash setup
          dhcp = {
            active = false;
          };
          dns = {
            domain = tld;
            inherit (opts.dns) interface upstreams;
            domainNeeded = true;
            expandHosts = true;

            piholePTR = "HOSTNAMEFQDN";
            # DNS records now managed by octodns
            hosts = opts.dns.extra_hosts;
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
  })))
