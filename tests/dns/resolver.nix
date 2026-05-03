_: {
  config,
  dns_test,
  lib,
  mylib,
  inputs,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;

  inherit
    (dns_test)
    resolver_ipv4
    subnet_cidr
    tld
    alpha_target
    beta_target
    alpha_body
    beta_body
    pihole_password
    pihole_password_hash
    fixture_port
    alpha_backend_port
    beta_backend_port
    tls_cert
    tls_key_b64
    ;

  fixture_dir = pkgs.writeTextDir "dns-test-fixtures/hosts.txt" ''
    0.0.0.0 ads.vm.test
    0.0.0.0 tracker.vm.test
  '';
  fixture_macvendor = pkgs.writeTextDir "dns-test-fixtures/macvendor.db" ''
    deterministic-macvendor-db
  '';

  fixture_root = pkgs.runCommand "dns-test-pihole-fixtures" {} ''
    mkdir -p "$out"
    cp ${fixture_dir}/dns-test-fixtures/hosts.txt "$out/hosts.txt"
    cp ${fixture_macvendor}/dns-test-fixtures/macvendor.db "$out/macvendor.db"
  '';

  tls_cert_path = pkgs.writeText "dns-test-local-cert.pem" tls_cert;
  tls_key_path = pkgs.runCommand "dns-test-local-key.pem" {} ''
    printf '%s' '${tls_key_b64}' | ${pkgs.coreutils}/bin/base64 -d > "$out"
  '';

  backend_script = pkgs.writeText "dns-test-backend.py" ''
    import argparse
    from http.server import BaseHTTPRequestHandler, HTTPServer

    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--body", required=True)
    args = parser.parse_args()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            body = args.body.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *values: object) -> None:
            return

    HTTPServer((args.bind, args.port), Handler).serve_forever()
  '';

  mk_backend_service = port: body: {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${backend_script} --bind 127.0.0.1 --port ${toString port} --body ${body}";
      Restart = "always";
      RestartSec = 1;
    };
  };

  octodns_config = pkgs.runCommand "dns-test-octodns-config" {} ''
    mkdir -p "$out/zones"
    cat > "$out/config.yaml" <<EOF
    providers:
      config:
        class: octodns.provider.yaml.YamlProvider
        directory: $out/zones
        default_ttl: 60
        enforce_order: false
      pihole:
        class: octodns_pihole.PiholeProvider
        url: http://127.0.0.1:1111
        password: env/PIHOLE_PASSWORD
        strict_supports: false
    zones:
      ${tld}.:
        sources:
          - config
        targets:
          - pihole
    EOF
    cat > "$out/zones/${tld}.yaml" <<'EOF'
    ---
    ${alpha_target}:
      type: A
      value: ${resolver_ipv4}
    ${beta_target}:
      type: A
      value: ${resolver_ipv4}
    EOF
  '';
in {
  imports = [
    ../base_node.nix
    ../_sops_stub.nix
    ../../_modules/options.nix
    inputs.nixos-dns.nixosModules.dns
    ../../systems/_modules/dns/default.nix
    ../../users/_units/reverse-proxy/default.nix
    ../../users/_units/pihole/default.nix
    ../../users/_units/octodns/default.nix
  ];

  system.stateVersion = "25.11";

  my = {
    nix.hostname = "resolver";
    nix.username = "tester";

    dns = o.def {
      inherit tld;
      main_dns = [resolver_ipv4];
      fallback_dns = [];
    };

    vhosts = {
      alpha = {
        target = alpha_target;
        sources = ["http://127.0.0.1:${toString alpha_backend_port}"];
      };
      beta = {
        target = beta_target;
        sources = ["http://127.0.0.1:${toString beta_backend_port}"];
      };
    };

    "unit.pihole" = {
      enable = true;
      dns.interface = "eth1";
    };

    "unit.octodns" = {
      enable = true;
      config_path = "${octodns_config}/config.yaml";
      use_cloudflare_token = false;
    };

    "unit.traefik" = {
      enable = true;
      lan_source_ranges = [subnet_cidr "127.0.0.1/32"];
      tls = {
        mode = "local";
        cert_path = tls_cert_path;
        key_path = tls_key_path;
      };
    };
  };

  virtualisation.vlans = [1];

  networking.interfaces.eth1 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = resolver_ipv4;
        prefixLength = 24;
      }
    ];
  };

  networking.firewall.allowPing = true;

  users.users.tester = {
    isNormalUser = true;
    home = "/home/tester";
  };

  environment.systemPackages = with pkgs; [
    curl
    jq
    python3
  ];

  system.activationScripts."dns-test-secrets" = lib.stringAfter ["users" "specialfs"] ''
    install -d -m755 /run/secrets
    printf '%s' '${pihole_password}' > /run/secrets/pihole_password
    printf '%s' '${pihole_password_hash}' > /run/secrets/pihole_password_hash
    chown pihole:pihole /run/secrets/pihole_password /run/secrets/pihole_password_hash
    chmod 0400 /run/secrets/pihole_password /run/secrets/pihole_password_hash
  '';

  # The fixture server replaces Pi-hole's production internet fetches with stable VM-local data
  # so pihole-ftl-setup.service can succeed with ExecMainStatus=0 in the test environment.
  systemd.services = {
    dns-test-fixture = {
      wantedBy = ["multi-user.target"];
      requiredBy = ["pihole-ftl-setup.service"];
      before = ["pihole-ftl-setup.service"];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString fixture_port} --bind 127.0.0.1 --directory ${fixture_root}";
        Restart = "always";
        RestartSec = 1;
      };
    };

    dns-backend-alpha = mk_backend_service alpha_backend_port alpha_body;
    dns-backend-beta = mk_backend_service beta_backend_port beta_body;
  };

  services.pihole-ftl = {
    lists = lib.mkForce [
      {
        url = "http://127.0.0.1:${toString fixture_port}/hosts.txt";
        type = "block";
        enabled = true;
        description = "DNS suite local hosts fixture";
      }
    ];
    macvendorURL = lib.mkForce "http://127.0.0.1:${toString fixture_port}/macvendor.db";
  };
}
