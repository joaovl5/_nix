_: {pkgs, ...}: let
  primary_ipv4 = "192.0.44.3";
  primary_ipv6 = "fd00:44::3";
  remote_ipv4 = "192.0.44.30";
  remote_ipv6 = "fd00:44::30";
  log_dir = "/run/netns-test";

  observer_script = pkgs.writeText "network-namespace-probe-observer.py" ''
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
            parsed = urllib.parse.urlparse(self.path)
            token = urllib.parse.parse_qs(parsed.query).get("token", [parsed.path.lstrip("/") or "-"])[0]
            source = self.client_address[0]
            os.makedirs(os.path.dirname(args.log), exist_ok=True)
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

  listener_script = pkgs.writeText "network-namespace-probe-listener.py" ''
    import argparse
    import os
    import socket

    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("tcp", "udp"))
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    args = parser.parse_args()

    family = socket.AF_INET6 if ":" in args.bind else socket.AF_INET

    def append(raw: bytes, source: str) -> None:
        token = raw.decode("utf-8", errors="replace").strip() or "<empty>"
        os.makedirs(os.path.dirname(args.log), exist_ok=True)
        with open(args.log, "a", encoding="utf-8") as handle:
            handle.write(f"{token.splitlines()[0]} {source}\n")

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
                append(payload, addr[0])
                conn.sendall(payload)
    else:
        sock = socket.socket(family, socket.SOCK_DGRAM)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.bind((args.bind, args.port))
        while True:
            payload, addr = sock.recvfrom(4096)
            append(payload, addr[0])
            sock.sendto(payload, addr)
  '';

  dnsmasq_ipv4_conf = pkgs.writeText "network-namespace-dnsmasq-v4.conf" ''
    bind-interfaces
    port=53
    listen-address=${primary_ipv4}
    no-daemon
    no-hosts
    no-resolv
    address=/allowed.core-test.internal/${primary_ipv4}
  '';

  dnsmasq_ipv6_conf = pkgs.writeText "network-namespace-dnsmasq-v6.conf" ''
    bind-interfaces
    port=53
    listen-address=${primary_ipv6}
    no-daemon
    no-hosts
    no-resolv
    address=/allowed.core-test.internal/${primary_ipv6}
  '';

  mk_observer = _name: bind: log_name: {
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

  mk_listener = _name: mode: bind: port: log_name: {
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
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
  ];

  system.stateVersion = "25.11";

  my.nix.hostname = "netns-probe";
  my.nix.username = "tester";

  virtualisation.vlans = [1];

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
        address = "10.44.0.0";
        prefixLength = 24;
        via = "192.0.44.2";
      }
      {
        address = "10.45.0.0";
        prefixLength = 24;
        via = "192.0.44.2";
      }
    ];
    ipv6.routes = [
      {
        address = "fd44:1::";
        prefixLength = 64;
        via = "fd00:44::2";
      }
      {
        address = "fd45:1::";
        prefixLength = 64;
        via = "fd00:44::2";
      }
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [53 853 18081 18443];
    allowedUDPPorts = [53 853 18081 18443];
    allowPing = true;
  };

  environment.systemPackages = with pkgs; [
    dnsmasq
    iproute2
    netcat-openbsd
    python3
    socat
  ];

  systemd.tmpfiles.rules = [
    "d ${log_dir} 0755 root root -"
  ];

  # Primary addresses are allowed resolver/source observers; remote addresses are
  # denied DNS/DoT/DoH sentinels. The driver preflights each denied listener before
  # asserting that namespace egress cannot reach it.
  systemd.services = {
    observer-v4 = mk_observer "observer-v4" primary_ipv4 "observer-v4.log";
    observer-v6 = mk_observer "observer-v6" primary_ipv6 "observer-v6.log";

    dnsmasq-v4 = {
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --conf-file=${dnsmasq_ipv4_conf}";
        Restart = "always";
        RestartSec = 1;
      };
    };
    dnsmasq-v6 = {
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --conf-file=${dnsmasq_ipv6_conf}";
        Restart = "always";
        RestartSec = 1;
      };
    };

    denied-dns-tcp-v4 = mk_listener "denied-dns-tcp-v4" "tcp" remote_ipv4 53 "denied-dns-tcp-v4.log";
    denied-dns-udp-v4 = mk_listener "denied-dns-udp-v4" "udp" remote_ipv4 53 "denied-dns-udp-v4.log";
    denied-dot-tcp-v4 = mk_listener "denied-dot-tcp-v4" "tcp" remote_ipv4 853 "denied-dot-tcp-v4.log";
    denied-dot-udp-v4 = mk_listener "denied-dot-udp-v4" "udp" remote_ipv4 853 "denied-dot-udp-v4.log";
    denied-doh-tcp-v4 = mk_listener "denied-doh-tcp-v4" "tcp" remote_ipv4 18443 "denied-doh-tcp-v4.log";
    denied-doh-udp-v4 = mk_listener "denied-doh-udp-v4" "udp" remote_ipv4 18443 "denied-doh-udp-v4.log";

    denied-dns-tcp-v6 = mk_listener "denied-dns-tcp-v6" "tcp" remote_ipv6 53 "denied-dns-tcp-v6.log";
    denied-dns-udp-v6 = mk_listener "denied-dns-udp-v6" "udp" remote_ipv6 53 "denied-dns-udp-v6.log";
    denied-dot-tcp-v6 = mk_listener "denied-dot-tcp-v6" "tcp" remote_ipv6 853 "denied-dot-tcp-v6.log";
    denied-dot-udp-v6 = mk_listener "denied-dot-udp-v6" "udp" remote_ipv6 853 "denied-dot-udp-v6.log";
    denied-doh-tcp-v6 = mk_listener "denied-doh-tcp-v6" "tcp" remote_ipv6 18443 "denied-doh-tcp-v6.log";
    denied-doh-udp-v6 = mk_listener "denied-doh-udp-v6" "udp" remote_ipv6 18443 "denied-doh-udp-v6.log";
  };
}
