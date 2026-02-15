{
  mylib,
  config,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
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
    data_dir = opt "Directory for pihole state data" t.str "${my.units.data_dir}/pihole";
    dns = {
      domain = opt "LAN domain" t.str "local";
      interface = opt "Network interface" t.str null;
    };
    web = {
      ports = opt "Web UI ports" (t.listOf t.int) [1111];
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
    sops.secrets = {
      "pihole_api_key" = s.mk_secret "${s.dir}/dns.yaml" "pihole-api-key" {
        owner = user;
        inherit group;
      };
    };

    system.activationScripts.ensure_data_directory = ''
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
        inherit (opts.web) ports;
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
  })))
