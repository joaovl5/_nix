_: {pkgs, ...}: let
  primary_ipv4 = "192.0.2.3";
  primary_ipv6 = "fd00:1::3";
  remote_ipv4 = "192.0.2.30";
  remote_ipv6 = "fd00:1::30";
  log_dir = "/run/wg-test";

  observer_script = pkgs.writeText "wireguard-test-probe-observer.py" ''
    import argparse
    import os
    import socket
    import urllib.parse
    from http.server import BaseHTTPRequestHandler, HTTPServer

    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    family = socket.AF_INET6 if ":" in args.bind else socket.AF_INET

    class Server(HTTPServer):
        address_family = family

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            os.makedirs(os.path.dirname(args.log), exist_ok=True)
            parsed = urllib.parse.urlparse(self.path)
            token = urllib.parse.parse_qs(parsed.query).get("token", [parsed.path.lstrip("/") or "-"])[0]
            source = self.client_address[0]
            with open(args.log, "a", encoding="utf-8") as handle:
                handle.write(f"{token} {source}\n")
            body = source.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *values: object) -> None:
            return

    os.makedirs(os.path.dirname(args.log), exist_ok=True)
    Server((args.bind, args.port), Handler).serve_forever()
  '';

  leak_listener_script = pkgs.writeText "wireguard-test-probe-leak-listener.py" ''
    import argparse
    import os
    import socket

    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("tcp", "udp"))
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--body", default="ok")
    args = parser.parse_args()

    family = socket.AF_INET6 if ":" in args.bind else socket.AF_INET

    def append_log(raw: bytes, source: str) -> None:
        text = raw.decode("utf-8", errors="replace").strip()
        token = text.splitlines()[0] if text else "<empty>"
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
                append_log(payload, addr[0])
                conn.sendall(payload if payload else args.body.encode("utf-8"))
    else:
        sock = socket.socket(family, socket.SOCK_DGRAM)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.bind((args.bind, args.port))
        while True:
            payload, addr = sock.recvfrom(4096)
            append_log(payload, addr[0])
            sock.sendto(payload, addr)
  '';

  dnsmasq_ipv4_conf = pkgs.writeText "wireguard-test-dnsmasq-v4.conf" ''
    bind-interfaces
    port=53
    listen-address=${primary_ipv4}
    no-daemon
    no-hosts
    no-resolv
    log-queries
    log-facility=${log_dir}/dns-approved-v4.log
    address=/.wg-test.internal/${primary_ipv4}
  '';

  dnsmasq_ipv6_conf = pkgs.writeText "wireguard-test-dnsmasq-v6.conf" ''
    bind-interfaces
    port=53
    listen-address=${primary_ipv6}
    no-daemon
    no-hosts
    no-resolv
    log-queries
    log-facility=${log_dir}/dns-approved-v6.log
    address=/.wg-test.internal/${primary_ipv6}
  '';

  mk_observer_service = _name: bind: log_name: {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    preStart = ''
      mkdir -p ${log_dir}
    '';
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${observer_script} --bind ${bind} --port 18081 --log ${log_dir}/${log_name}";
      Restart = "always";
      RestartSec = 1;
    };
  };

  mk_leak_service = {
    mode,
    bind,
    port,
    log_name,
    ...
  }: {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    preStart = ''
      mkdir -p ${log_dir}
    '';
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${leak_listener_script} ${mode} --bind ${bind} --port ${toString port} --log ${log_dir}/${log_name}";
      Restart = "always";
      RestartSec = 1;
    };
  };
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
  ];

  system.stateVersion = "25.11";

  systemd.tmpfiles.rules = [
    "d ${log_dir} 0755 root root -"
  ];

  my.nix.hostname = "probe";
  my.nix.username = "tester";

  virtualisation.vlans = [1];

  # Probe keeps two addresses per family on one NIC: the primary address is the approved shared
  # VLAN fixture for positive controls, while the remote /32 and /128 model destinations that
  # confined traffic must reach over WireGuard rather than directly on the LAN.
  networking.interfaces.eth1 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = primary_ipv4;
        prefixLength = 24;
      }
      {
        address = remote_ipv4;
        prefixLength = 32;
      }
    ];
    ipv6.addresses = [
      {
        address = primary_ipv6;
        prefixLength = 64;
      }
      {
        address = remote_ipv6;
        prefixLength = 128;
      }
    ];
    ipv4.routes = [
      {
        address = "10.15.0.0";
        prefixLength = 24;
        via = "192.0.2.2";
      }
    ];
    ipv6.routes = [
      {
        address = "fd93:9701:1d00::";
        prefixLength = 64;
        via = "fd00:1::2";
      }
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [53 853 18081 18443];
    allowedUDPPorts = [53 853 18081];
  };

  environment.systemPackages = with pkgs; [
    curl
    python3
    socat
    netcat-openbsd
    dnsmasq
    dnsutils
  ];

  # These listeners are the observable external world for the suite: source observers on the
  # approved addresses, plus DNS/DoT/DoH leak endpoints on the remote addresses.
  systemd.services = {
    probe-observer-primary-v4 = mk_observer_service "probe-observer-primary-v4" primary_ipv4 "observer-primary-v4.log";
    probe-observer-primary-v6 = mk_observer_service "probe-observer-primary-v6" primary_ipv6 "observer-primary-v6.log";
    probe-observer-remote-v4 = mk_observer_service "probe-observer-remote-v4" remote_ipv4 "observer-remote-v4.log";
    probe-observer-remote-v6 = mk_observer_service "probe-observer-remote-v6" remote_ipv6 "observer-remote-v6.log";

    probe-dns-approved-v4 = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      preStart = ''
        mkdir -p ${log_dir}
      '';
      serviceConfig = {
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --conf-file=${dnsmasq_ipv4_conf}";
        Restart = "always";
        RestartSec = 1;
      };
    };

    probe-dns-approved-v6 = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      preStart = ''
        mkdir -p ${log_dir}
      '';
      serviceConfig = {
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --conf-file=${dnsmasq_ipv6_conf}";
        Restart = "always";
        RestartSec = 1;
      };
    };

    probe-dns-leak-udp-v4 = mk_leak_service {
      name = "probe-dns-leak-udp-v4";
      mode = "udp";
      bind = remote_ipv4;
      port = 53;
      log_name = "dns-leak-udp-v4.log";
    };
    probe-dns-leak-udp-v6 = mk_leak_service {
      name = "probe-dns-leak-udp-v6";
      mode = "udp";
      bind = remote_ipv6;
      port = 53;
      log_name = "dns-leak-udp-v6.log";
    };
    probe-dns-leak-tcp-v4 = mk_leak_service {
      name = "probe-dns-leak-tcp-v4";
      mode = "tcp";
      bind = remote_ipv4;
      port = 53;
      log_name = "dns-leak-tcp-v4.log";
    };
    probe-dns-leak-tcp-v6 = mk_leak_service {
      name = "probe-dns-leak-tcp-v6";
      mode = "tcp";
      bind = remote_ipv6;
      port = 53;
      log_name = "dns-leak-tcp-v6.log";
    };
    probe-dot-leak-udp-v4 = mk_leak_service {
      name = "probe-dot-leak-udp-v4";
      mode = "udp";
      bind = remote_ipv4;
      port = 853;
      log_name = "dot-leak-udp-v4.log";
    };
    probe-dot-leak-udp-v6 = mk_leak_service {
      name = "probe-dot-leak-udp-v6";
      mode = "udp";
      bind = remote_ipv6;
      port = 853;
      log_name = "dot-leak-udp-v6.log";
    };
    probe-dot-leak-tcp-v4 = mk_leak_service {
      name = "probe-dot-leak-tcp-v4";
      mode = "tcp";
      bind = remote_ipv4;
      port = 853;
      log_name = "dot-leak-tcp-v4.log";
    };
    probe-dot-leak-tcp-v6 = mk_leak_service {
      name = "probe-dot-leak-tcp-v6";
      mode = "tcp";
      bind = remote_ipv6;
      port = 853;
      log_name = "dot-leak-tcp-v6.log";
    };
    probe-doh-leak-v4 = mk_leak_service {
      name = "probe-doh-leak-v4";
      mode = "tcp";
      bind = remote_ipv4;
      port = 18443;
      log_name = "doh-leak-v4.log";
    };
    probe-doh-leak-v6 = mk_leak_service {
      name = "probe-doh-leak-v6";
      mode = "tcp";
      bind = remote_ipv6;
      port = 18443;
      log_name = "doh-leak-v6.log";
    };
  };
}
