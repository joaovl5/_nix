_: {
  lib,
  inputs,
  pkgs,
  test_wireguard_keys,
  ...
}: let
  readKey = name: lib.removeSuffix "\n" (builtins.readFile "${test_wireguard_keys}/${name}");
  wgDemoScript = pkgs.writeText "wireguard-test-demo.py" ''
    from http.server import BaseHTTPRequestHandler, HTTPServer

    BODY = b"isolated-through-wg"

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(BODY)))
            self.end_headers()
            self.wfile.write(BODY)

        def log_message(self, format, *args):
            return

    HTTPServer(("11.1.0.11", 18080), Handler).serve_forever()
  '';
in {
  imports = [
    ../base_node.nix
    ../../_modules/options.nix
    ../_sops_stub.nix
    ../../users/_units/wireguard/default.nix
    inputs.nixarr.inputs.vpnconfinement.nixosModules.default
  ];

  system = {
    stateVersion = "25.11";
    activationScripts."wireguard-test-secrets" = lib.stringAfter ["specialfs"] ''
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/isolated-host.private /run/secrets/wg_tyrant_priv
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/isolated-namespace.private /run/secrets/wg_vpn_priv
    '';
  };

  virtualisation.vlans = [1];

  networking.firewall.allowedTCPPorts = [18080];

  environment.systemPackages = with pkgs; [
    wireguard-tools
    curl
    iproute2
    python3
  ];

  systemd.services = {
    wg-demo = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      preStart = ''
        while ! ${pkgs.iproute2}/bin/ip -o -4 addr show dev wg-host | ${pkgs.gnugrep}/bin/grep -q '11\.1\.0\.11/32'; do
          ${pkgs.coreutils}/bin/sleep 1
        done
      '';
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${wgDemoScript}";
        Restart = "always";
        RestartSec = 1;
      };
    };

    plain-demo = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        ${pkgs.curl}/bin/curl --fail --silent --show-error http://probe:18081 > /run/plain-demo-source-ip
      '';
    };

    confined-demo = {
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        ${pkgs.curl}/bin/curl --fail --silent --show-error http://probe:18081 > /run/confined-demo-source-ip
      '';
    };
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
      };
      extra_peers = [
        {
          publicKey = readKey "relay.public";
          allowedIPs = ["11.1.0.0/24"];
          endpoint = "relay:51820";
          persistentKeepalive = 25;
        }
      ];
      client = {
        enable = true;
        namespace = "wg";
        address = "11.1.0.12/32";
        endpoint = "relay:51820";
        server_public_key = readKey "relay.public";
        persistent_keepalive = 25;
        dns = "192.0.2.53";
        confined_services = ["confined-demo"];
      };
    };
  };
}
