_: {
  pkgs,
  azure_vpn_lab,
  ...
}: let
  cfg = azure_vpn_lab;
  log_dir = "/run/azure-vpn-lab";
  log_path = "${log_dir}/resource.log";

  resource_server =
    pkgs.writeText "azure-vpn-lab-resource.py"
    # python
    ''
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

      class Handler(BaseHTTPRequestHandler):
          def do_GET(self) -> None:
              os.makedirs(os.path.dirname(args.log), exist_ok=True)
              parsed = urllib.parse.urlparse(self.path)
              token = urllib.parse.parse_qs(parsed.query).get("token", ["-"])[0]
              source = self.client_address[0]
              with open(args.log, "a", encoding="utf-8") as handle:
                  handle.write(f"{token} {source}\n")
              body = f"{token} {source}\n".encode("utf-8")
              self.send_response(200)
              self.send_header("Content-Type", "text/plain; charset=utf-8")
              self.send_header("Content-Length", str(len(body)))
              self.end_headers()
              self.wfile.write(body)

          def log_message(self, format: str, *values: object) -> None:
              return

      sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
      sock.bind((args.bind, args.port))
      sock.listen()
      HTTPServer.address_family = socket.AF_INET
      server = HTTPServer((args.bind, args.port), Handler, False)
      server.socket = sock
      server.server_bind = lambda: None
      server.server_activate = lambda: None
      server.serve_forever()
    '';
in {
  imports = [
    ../../common/base_node.nix
    (import ../../../modules/aspects/base/options.nix {}).den.aspects.base-options.nixos
  ];

  system.stateVersion = "25.11";

  my.nix.hostname = "azure-private-resource";
  my.nix.username = "tester";

  virtualisation.vlans = [2];

  networking = {
    interfaces.eth1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = cfg.private.resource_ipv4;
          prefixLength = cfg.private.prefix_length;
        }
      ];
    };
    defaultGateway = cfg.private.gateway_ipv4;
    firewall = {
      allowedTCPPorts = [cfg.private.service_port];
      allowPing = true;
    };
  };

  environment.systemPackages = with pkgs; [
    curl
    iproute2
    python3
  ];

  systemd.tmpfiles.rules = [
    "d ${log_dir} 0755 root root -"
  ];

  systemd.services.azure-private-resource = {
    description = "Azure VPN lab private resource fixture";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    preStart = ''
      mkdir -p ${log_dir}
    '';
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${resource_server} --bind ${cfg.private.resource_ipv4} --port ${toString cfg.private.service_port} --log ${log_path}";
      Restart = "always";
      RestartSec = 1;
    };
  };
}
