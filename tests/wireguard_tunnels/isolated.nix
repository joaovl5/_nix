_: {
  lib,
  pkgs,
  test_wireguard_keys,
  ...
}: let
  read_key = name: lib.removeSuffix "\n" (builtins.readFile "${test_wireguard_keys}/${name}");

  shared_vlan_ipv4 = "192.0.2.2";
  shared_vlan_ipv6 = "fd00:1::2";
  probe_primary_ipv4 = "192.0.2.3";
  probe_primary_ipv6 = "fd00:1::3";
  probe_remote_ipv4 = "192.0.2.30";
  probe_remote_ipv6 = "fd00:1::30";
  wireguard_host_ipv4 = "11.1.0.11";
  wireguard_host_ipv6 = "fd11:1::11";
  namespace_ipv4 = "11.1.0.12/32";
  namespace_ipv6 = "fd11:1::12/128";
  log_dir = "/run/wg-test";

  listener_script = pkgs.writeText "wireguard-test-listener.py" ''
    import argparse
    import os
    import socket
    import threading
    import urllib.parse
    from http.server import BaseHTTPRequestHandler, HTTPServer

    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("http", "tcp", "udp"))
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--body", default="ok")
    args = parser.parse_args()

    def ensure_log_dir() -> None:
        os.makedirs(os.path.dirname(args.log), exist_ok=True)

    def append_log(token: str, source: str) -> None:
        ensure_log_dir()
        with open(args.log, "a", encoding="utf-8") as handle:
            handle.write(f"{token} {source}\n")

    def decode_token(raw: bytes) -> str:
        text = raw.decode("utf-8", errors="replace").strip()
        if not text:
            return "<empty>"
        return text.splitlines()[0]

    family = socket.AF_INET6 if ":" in args.bind else socket.AF_INET

    if args.mode == "http":
        class Server(HTTPServer):
            address_family = family

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                parsed = urllib.parse.urlparse(self.path)
                token = urllib.parse.parse_qs(parsed.query).get("token", [parsed.path.lstrip("/") or "-"])[0]
                append_log(token, self.client_address[0])
                body = args.body.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format: str, *values: object) -> None:
                return

        ensure_log_dir()
        Server((args.bind, args.port), Handler).serve_forever()

    elif args.mode == "tcp":
        def serve_tcp() -> None:
            ensure_log_dir()
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
                    append_log(decode_token(payload), addr[0])
                    conn.sendall(payload if payload else args.body.encode("utf-8"))

        serve_tcp()

    else:
        def serve_udp() -> None:
            ensure_log_dir()
            sock = socket.socket(family, socket.SOCK_DGRAM)
            if family == socket.AF_INET6:
                sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
            sock.bind((args.bind, args.port))
            while True:
                payload, addr = sock.recvfrom(4096)
                append_log(decode_token(payload), addr[0])
                sock.sendto(payload, addr)

        serve_udp()
  '';

  curl_capture = name: url: vpn:
    {
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        mkdir -p ${log_dir}
        ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 5 ${lib.escapeShellArg url} > ${log_dir}/${name}
      '';
    }
    // lib.optionalAttrs vpn {
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
    };

  mk_http_service = {
    name,
    bind,
    port,
    body,
    log_name,
    vpn ? false,
    after ? [],
    pre_start ? null,
  }:
    lib.nameValuePair name ({
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"] ++ after;
        wants = ["network-online.target"];
        preStart =
          if pre_start == null
          then ''
            mkdir -p ${log_dir}
          ''
          else ''
            mkdir -p ${log_dir}
            ${pre_start}
          '';
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${listener_script} http --bind ${lib.escapeShellArg bind} --port ${toString port} --log ${lib.escapeShellArg "${log_dir}/${log_name}"} --body ${lib.escapeShellArg body}";
          Restart = "always";
          RestartSec = 1;
        };
      }
      // lib.optionalAttrs vpn {
        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg";
        };
      });

  mk_socket_service = {
    name,
    mode,
    bind,
    port,
    body ? "ok",
    log_name,
    vpn ? false,
    after ? [],
  }:
    lib.nameValuePair name ({
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"] ++ after;
        wants = ["network-online.target"];
        preStart = ''
          mkdir -p ${log_dir}
        '';
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${listener_script} ${mode} --bind ${lib.escapeShellArg bind} --port ${toString port} --log ${lib.escapeShellArg "${log_dir}/${log_name}"} --body ${lib.escapeShellArg body}";
          Restart = "always";
          RestartSec = 1;
        };
      }
      // lib.optionalAttrs vpn {
        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg";
        };
      });

  host_services = builtins.listToAttrs [
    (mk_http_service {
      name = "wg-demo";
      bind = wireguard_host_ipv4;
      port = 18080;
      body = "isolated-through-wg";
      log_name = "relay-forward-tcp-v4.log";
      after = ["wireguard-wg-host.service"];
      pre_start = ''
        while ! ${pkgs.iproute2}/bin/ip -o -4 addr show dev wg-host | ${pkgs.gnugrep}/bin/grep -q '11\.1\.0\.11/32'; do
          ${pkgs.coreutils}/bin/sleep 1
        done
        while ! ${pkgs.iproute2}/bin/ip -o -6 addr show dev wg-host | ${pkgs.gnugrep}/bin/grep -q 'fd11:1::11/128'; do
          ${pkgs.coreutils}/bin/sleep 1
        done
      '';
    })
    (mk_http_service {
      name = "wg-demo-v6";
      bind = wireguard_host_ipv6;
      port = 18080;
      body = "isolated-through-wg";
      log_name = "relay-forward-tcp-v6.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-tcp-opposite-v4";
      mode = "udp";
      bind = wireguard_host_ipv4;
      port = 18080;
      log_name = "relay-forward-tcp-opposite-v4.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-tcp-opposite-v6";
      mode = "udp";
      bind = wireguard_host_ipv6;
      port = 18080;
      log_name = "relay-forward-tcp-opposite-v6.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-udp-v4";
      mode = "udp";
      bind = wireguard_host_ipv4;
      port = 18082;
      log_name = "relay-forward-udp-v4.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-udp-v6";
      mode = "udp";
      bind = wireguard_host_ipv6;
      port = 18082;
      log_name = "relay-forward-udp-v6.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-udp-opposite-v4";
      mode = "tcp";
      bind = wireguard_host_ipv4;
      port = 18082;
      body = "relay-forward-udp-opposite";
      log_name = "relay-forward-udp-opposite-v4.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-udp-opposite-v6";
      mode = "tcp";
      bind = wireguard_host_ipv6;
      port = 18082;
      body = "relay-forward-udp-opposite";
      log_name = "relay-forward-udp-opposite-v6.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-both-tcp-v4";
      mode = "tcp";
      bind = wireguard_host_ipv4;
      port = 18084;
      log_name = "relay-forward-both-tcp-v4.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-both-tcp-v6";
      mode = "tcp";
      bind = wireguard_host_ipv6;
      port = 18084;
      log_name = "relay-forward-both-tcp-v6.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-both-udp-v4";
      mode = "udp";
      bind = wireguard_host_ipv4;
      port = 18084;
      log_name = "relay-forward-both-udp-v4.log";
      after = ["wireguard-wg-host.service"];
    })
    (mk_socket_service {
      name = "relay-forward-both-udp-v6";
      mode = "udp";
      bind = wireguard_host_ipv6;
      port = 18084;
      log_name = "relay-forward-both-udp-v6.log";
      after = ["wireguard-wg-host.service"];
    })
  ];

  namespace_services = builtins.listToAttrs [
    (mk_socket_service {
      name = "ns-port-map-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 28080;
      log_name = "namespace-port-map-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-tcp-opposite-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 28080;
      log_name = "namespace-port-map-tcp-opposite-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 28080;
      log_name = "namespace-port-map-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 28082;
      log_name = "namespace-port-map-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-udp-opposite-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 28082;
      log_name = "namespace-port-map-udp-opposite-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-udp-v6";
      mode = "udp";
      bind = "::";
      port = 28082;
      log_name = "namespace-port-map-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-both-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 28084;
      log_name = "namespace-port-map-both-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-both-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 28084;
      log_name = "namespace-port-map-both-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-both-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 28084;
      log_name = "namespace-port-map-both-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-port-map-both-udp-v6";
      mode = "udp";
      bind = "::";
      port = 28084;
      log_name = "namespace-port-map-both-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-unmapped-denied-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 28090;
      log_name = "namespace-unmapped-denied-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-unmapped-denied-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 28090;
      log_name = "namespace-unmapped-denied-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-unmapped-denied-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 28092;
      log_name = "namespace-unmapped-denied-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-unmapped-denied-udp-v6";
      mode = "udp";
      bind = "::";
      port = 28092;
      log_name = "namespace-unmapped-denied-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 55080;
      log_name = "namespace-open-vpn-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 55080;
      log_name = "namespace-open-vpn-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 55082;
      log_name = "namespace-open-vpn-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-udp-v6";
      mode = "udp";
      bind = "::";
      port = 55082;
      log_name = "namespace-open-vpn-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-both-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 55084;
      log_name = "namespace-open-vpn-both-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-both-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 55084;
      log_name = "namespace-open-vpn-both-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-both-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 55084;
      log_name = "namespace-open-vpn-both-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-both-udp-v6";
      mode = "udp";
      bind = "::";
      port = 55084;
      log_name = "namespace-open-vpn-both-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-denied-tcp-v4";
      mode = "tcp";
      bind = "0.0.0.0";
      port = 55090;
      log_name = "namespace-open-vpn-denied-tcp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-denied-tcp-v6";
      mode = "tcp";
      bind = "::";
      port = 55090;
      log_name = "namespace-open-vpn-denied-tcp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-denied-udp-v4";
      mode = "udp";
      bind = "0.0.0.0";
      port = 55092;
      log_name = "namespace-open-vpn-denied-udp-v4.log";
      vpn = true;
      after = ["wg.service"];
    })
    (mk_socket_service {
      name = "ns-open-vpn-denied-udp-v6";
      mode = "udp";
      bind = "::";
      port = 55092;
      log_name = "namespace-open-vpn-denied-udp-v6.log";
      vpn = true;
      after = ["wg.service"];
    })
  ];
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
    ../_sops_stub.nix
    ../../users/_units/wireguard/default.nix
  ];

  system = {
    stateVersion = "25.11";
    activationScripts."wireguard-test-secrets" = lib.stringAfter ["specialfs"] ''
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/isolated-host.private /run/secrets/wg_tyrant_priv
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/isolated-namespace.private /run/secrets/wg_vpn_priv
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${log_dir} 0755 root root -"
  ];

  virtualisation.vlans = [1];

  networking.interfaces.eth1 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = shared_vlan_ipv4;
        prefixLength = 24;
      }
    ];
    ipv6.addresses = [
      {
        address = shared_vlan_ipv6;
        prefixLength = 64;
      }
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [18080 18082 18084 19080 19084 19090];
    allowedUDPPorts = [18080 18082 18084 19082 19084 19092];
    extraCommands = ''
      iptables -A FORWARD -i eth1 -o wg-br -j ACCEPT
      iptables -A FORWARD -i wg-br -o eth1 -j ACCEPT
      ip6tables -A FORWARD -i eth1 -o wg-br -j ACCEPT
      ip6tables -A FORWARD -i wg-br -o eth1 -j ACCEPT
    '';
    extraStopCommands = ''
      ip6tables -D FORWARD -i wg-br -o eth1 -j ACCEPT || true
      ip6tables -D FORWARD -i eth1 -o wg-br -j ACCEPT || true
      iptables -D FORWARD -i wg-br -o eth1 -j ACCEPT || true
      iptables -D FORWARD -i eth1 -o wg-br -j ACCEPT || true
    '';
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
    curl
    iproute2
    socat
    netcat-openbsd
    python3
    dnsutils
  ];

  systemd.services =
    host_services
    // namespace_services
    // {
      plain-demo = curl_capture "plain-demo-source-ip" "http://${probe_primary_ipv4}:18081/primary-v4" false;
      plain-demo-v6 = curl_capture "plain-demo-source-ip-v6" "http://[${probe_primary_ipv6}]:18081/primary-v6" false;
      confined-demo = curl_capture "confined-demo-source-ip" "http://${probe_remote_ipv4}:18081/remote-v4" true;
      confined-demo-v6 = curl_capture "confined-demo-source-ip-v6" "http://[${probe_remote_ipv6}]:18081/remote-v6" true;
    };

  my = {
    nix.hostname = "isolated";
    nix.username = "tester";

    "unit.wireguard" = {
      enable = true;
      relay.enable = false;
      nat.enable = false;
      interfaces.internal = {
        name = "wg-host";
        privateKeyFile = "wg_tyrant_priv";
        listen_port = 51820;
        subnet = {
          ip = "11.1.0.11";
          mask = "32";
        };
        subnet_v6 = {
          ip = "fd11:1::11";
          mask = "128";
        };
      };
      extra_peers = [
        {
          publicKey = read_key "relay.public";
          allowedIPs = [
            "11.1.0.0/24"
            "fd11:1::/64"
          ];
          endpoint = "192.0.2.1:51820";
          persistentKeepalive = 25;
        }
      ];
      client = {
        enable = true;
        namespace = "wg";
        address = namespace_ipv4;
        address_v6 = namespace_ipv6;
        endpoint = "192.0.2.1:51820";
        server_public_key = read_key "relay.public";
        persistent_keepalive = 25;
        dns = [probe_primary_ipv4 probe_primary_ipv6];
        accessible_from = [
          "192.0.2.3/32"
          "fd00:1::3/128"
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
        open_vpn_ports = [
          {
            port = 55080;
            protocol = "tcp";
          }
          {
            port = 55082;
            protocol = "udp";
          }
          {
            port = 55084;
            protocol = "both";
          }
        ];
        strict_dns = {
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
        confined_services = [
          "confined-demo"
          "confined-demo-v6"
          "ns-port-map-tcp-v4"
          "ns-port-map-tcp-opposite-v4"
          "ns-port-map-tcp-v6"
          "ns-port-map-udp-v4"
          "ns-port-map-udp-opposite-v4"
          "ns-port-map-udp-v6"
          "ns-port-map-both-tcp-v4"
          "ns-port-map-both-tcp-v6"
          "ns-port-map-both-udp-v4"
          "ns-port-map-both-udp-v6"
          "ns-unmapped-denied-tcp-v4"
          "ns-unmapped-denied-tcp-v6"
          "ns-unmapped-denied-udp-v4"
          "ns-unmapped-denied-udp-v6"
          "ns-open-vpn-tcp-v4"
          "ns-open-vpn-tcp-v6"
          "ns-open-vpn-udp-v4"
          "ns-open-vpn-udp-v6"
          "ns-open-vpn-both-tcp-v4"
          "ns-open-vpn-both-tcp-v6"
          "ns-open-vpn-both-udp-v4"
          "ns-open-vpn-both-udp-v6"
          "ns-open-vpn-denied-tcp-v4"
          "ns-open-vpn-denied-tcp-v6"
          "ns-open-vpn-denied-udp-v4"
          "ns-open-vpn-denied-udp-v6"
        ];
      };
    };
  };
}
