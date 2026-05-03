_: {pkgs, ...}: let
  shared_ipv4 = "192.0.44.2";
  shared_ipv6 = "fd00:44::2";
  probe_primary_ipv4 = "192.0.44.3";
  probe_primary_ipv6 = "fd00:44::3";
  probe_remote_ipv4 = "192.0.44.30";
  probe_remote_ipv6 = "fd00:44::30";
  namespace_ipv4 = "10.44.0.2";
  namespace_ipv6 = "fd44:1::2";
  log_dir = "/run/netns-test";

  listener_script = pkgs.writeText "network-namespace-test-listener.py" ''
    import argparse
    import os
    import socket
    from http.server import BaseHTTPRequestHandler, HTTPServer

    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("tcp", "udp"))
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    family = socket.AF_INET6 if ":" in args.bind else socket.AF_INET

    def log(token: str, source: str) -> None:
        os.makedirs(os.path.dirname(args.log), exist_ok=True)
        with open(args.log, "a", encoding="utf-8") as handle:
            handle.write(f"{token} {source}\n")

    if args.mode == "tcp":
        sock = socket.socket(family, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.bind((args.bind, args.port))
        sock.listen()
        while True:
            conn, addr = sock.accept()
            with conn:
                payload = conn.recv(4096)
                token = payload.decode("utf-8", errors="replace").strip() or "<empty>"
                log(token.splitlines()[0], addr[0])
                conn.sendall(payload)
    else:
        sock = socket.socket(family, socket.SOCK_DGRAM)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.bind((args.bind, args.port))
        while True:
            payload, addr = sock.recvfrom(4096)
            token = payload.decode("utf-8", errors="replace").strip() or "<empty>"
            log(token.splitlines()[0], addr[0])
            sock.sendto(payload, addr)
  '';

  mk_listener = {
    name,
    mode,
    bind,
    port,
    log_name,
  }: {
    description = "Network namespace test listener ${name}";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    preStart = ''
      mkdir -p ${log_dir}
    '';
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${listener_script} ${mode} --bind ${bind} --port ${toString port} --log ${log_dir}/${log_name}";
      Restart = "always";
      RestartSec = 1;
    };
  };

  source_probe = name: url: {
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      mkdir -p ${log_dir}
      ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 5 ${url} > ${log_dir}/${name}
    '';
  };
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
    ../../users/_units/network_namespaces/default.nix
  ];

  system.stateVersion = "25.11";

  virtualisation.vlans = [1];

  networking.interfaces.eth1 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = shared_ipv4;
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = shared_ipv6;
        prefixLength = 64;
      }
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [19080 19084];
    allowedUDPPorts = [19082 19084];
    allowPing = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    iproute2
    iptables
    netcat-openbsd
    python3
    socat
  ];

  systemd.tmpfiles.rules = [
    "d ${log_dir} 0755 root root -"
  ];

  # Listener names, log files, and configured ports are a contract with the Python
  # driver. Keep these in sync with tests/scripts/src/my_nix_tests/network_namespaces.py.
  systemd.services = {
    ns-source-v4 = source_probe "source-v4" "http://${probe_primary_ipv4}:18081/source-v4";
    ns-source-v6 = source_probe "source-v6" "http://[${probe_primary_ipv6}]:18081/source-v6";
    ns-dns-lookup = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        mkdir -p ${log_dir}
        ${pkgs.dnsutils}/bin/dig +short allowed.core-test.internal > ${log_dir}/dns-lookup
      '';
    };

    ns-tcp-v4 = mk_listener {
      name = "ns-tcp-v4";
      mode = "tcp";
      bind = namespace_ipv4;
      port = 28080;
      log_name = "portmap-tcp-v4.log";
    };
    ns-tcp-v6 = mk_listener {
      name = "ns-tcp-v6";
      mode = "tcp";
      bind = namespace_ipv6;
      port = 28080;
      log_name = "portmap-tcp-v6.log";
    };
    ns-tcp-opposite-udp-v4 = mk_listener {
      name = "ns-tcp-opposite-udp-v4";
      mode = "udp";
      bind = namespace_ipv4;
      port = 28080;
      log_name = "portmap-tcp-opposite-udp-v4.log";
    };
    ns-tcp-opposite-udp-v6 = mk_listener {
      name = "ns-tcp-opposite-udp-v6";
      mode = "udp";
      bind = namespace_ipv6;
      port = 28080;
      log_name = "portmap-tcp-opposite-udp-v6.log";
    };
    ns-udp-v4 = mk_listener {
      name = "ns-udp-v4";
      mode = "udp";
      bind = namespace_ipv4;
      port = 28082;
      log_name = "portmap-udp-v4.log";
    };
    ns-udp-v6 = mk_listener {
      name = "ns-udp-v6";
      mode = "udp";
      bind = namespace_ipv6;
      port = 28082;
      log_name = "portmap-udp-v6.log";
    };
    ns-udp-opposite-tcp-v4 = mk_listener {
      name = "ns-udp-opposite-tcp-v4";
      mode = "tcp";
      bind = namespace_ipv4;
      port = 28082;
      log_name = "portmap-udp-opposite-tcp-v4.log";
    };
    ns-udp-opposite-tcp-v6 = mk_listener {
      name = "ns-udp-opposite-tcp-v6";
      mode = "tcp";
      bind = namespace_ipv6;
      port = 28082;
      log_name = "portmap-udp-opposite-tcp-v6.log";
    };
    ns-both-tcp-v4 = mk_listener {
      name = "ns-both-tcp-v4";
      mode = "tcp";
      bind = namespace_ipv4;
      port = 28084;
      log_name = "portmap-both-tcp-v4.log";
    };
    ns-both-tcp-v6 = mk_listener {
      name = "ns-both-tcp-v6";
      mode = "tcp";
      bind = namespace_ipv6;
      port = 28084;
      log_name = "portmap-both-tcp-v6.log";
    };
    ns-both-udp-v4 = mk_listener {
      name = "ns-both-udp-v4";
      mode = "udp";
      bind = namespace_ipv4;
      port = 28084;
      log_name = "portmap-both-udp-v4.log";
    };
    ns-both-udp-v6 = mk_listener {
      name = "ns-both-udp-v6";
      mode = "udp";
      bind = namespace_ipv6;
      port = 28084;
      log_name = "portmap-both-udp-v6.log";
    };
  };

  my = {
    nix = {
      hostname = "netns-host";
      username = "tester";
    };

    network_namespaces = {
      # The main backend-less namespace proves the reusable core without WireGuard.
      test = {
        enable = true;
        backend.type = "none";
        addresses = {
          host_v4 = "10.44.0.1";
          namespace_v4 = namespace_ipv4;
          host_v6 = "fd44:1::1";
          namespace_v6 = namespace_ipv6;
        };
        dns = {
          servers = [probe_primary_ipv4 probe_primary_ipv6];
          strict = {
            enable = true;
            block_doh_endpoints = [
              {
                family = "ipv4";
                address = probe_remote_ipv4;
                port = 18443;
              }
              {
                family = "ipv6";
                address = probe_remote_ipv6;
                port = 18443;
              }
            ];
          };
        };
        services = [
          "ns-source-v4"
          "ns-source-v6"
          "ns-dns-lookup"
          "ns-tcp-v4"
          "ns-tcp-v6"
          "ns-tcp-opposite-udp-v4"
          "ns-tcp-opposite-udp-v6"
          "ns-udp-v4"
          "ns-udp-v6"
          "ns-udp-opposite-tcp-v4"
          "ns-udp-opposite-tcp-v6"
          "ns-both-tcp-v4"
          "ns-both-tcp-v6"
          "ns-both-udp-v4"
          "ns-both-udp-v6"
        ];
        accessible_from = [
          "192.0.44.0/24"
          "fd00:44::/64"
        ];
        port_mappings = [
          {
            from = 19080;
            to = 28080;
            protocol = "tcp";
          }
          {
            from = 19082;
            to = 28082;
            protocol = "udp";
          }
          {
            from = 19084;
            to = 28084;
            protocol = "both";
          }
        ];
      };

      # `failcore` is healthy by default. The driver uses the internal setup-failure
      # environment trigger to force a core-only partial startup failure, then verifies cleanup.
      failcore = {
        enable = true;
        backend.type = "none";
        addresses = {
          host_v4 = "10.45.0.1";
          namespace_v4 = "10.45.0.2";
          host_v6 = "fd45:1::1";
          namespace_v6 = "fd45:1::2";
        };
        dns = {
          servers = [probe_primary_ipv4 probe_primary_ipv6];
          strict.enable = true;
        };
        accessible_from = [
          "192.0.44.0/24"
          "fd00:44::/64"
        ];
      };
    };
  };
}
