_: {pkgs, ...}: let
  observerScript = pkgs.writeText "wireguard-test-probe.py" ''
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = self.client_address[0].encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            return

    HTTPServer(("0.0.0.0", 18081), Handler).serve_forever()
  '';
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
  ];

  system.stateVersion = "25.11";

  my.nix.hostname = "probe";
  my.nix.username = "tester";

  virtualisation.vlans = [1];

  networking.firewall.allowedTCPPorts = [18081];

  environment.systemPackages = with pkgs; [
    curl
    python3
  ];

  systemd.services.probe-observer = {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${observerScript}";
      Restart = "always";
      RestartSec = 1;
    };
  };
}
