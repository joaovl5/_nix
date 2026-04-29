_: {
  lib,
  inputs,
  pkgs,
  test_wireguard_keys,
  ...
}: let
  readKey = name: lib.removeSuffix "\n" (builtins.readFile "${test_wireguard_keys}/${name}");
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
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/relay.private /run/secrets/wg_main_priv
    '';
  };

  virtualisation.vlans = [1];

  networking.firewall.allowedTCPPorts = [18080];

  environment.systemPackages = with pkgs; [
    wireguard-tools
    curl
    iproute2
  ];

  my = {
    nix.hostname = "relay";
    nix.username = "tester";

    "unit.wireguard" = {
      enable = true;
      relay = {
        enable = true;
        peer = {
          private_ip = "11.1.0.11";
          public_key = readKey "isolated-host.public";
        };
        forward = [
          {
            port_in = 18080;
            port_out = 18080;
          }
        ];
      };
      nat.enable = true;
      interfaces = {
        external.name = "eth1";
        internal = {
          name = "wg-host";
          listen_port = 51820;
          subnet = {
            ip = "11.1.0.1";
            mask = "24";
          };
        };
      };
      extra_peers = [
        {
          publicKey = readKey "isolated-namespace.public";
          allowedIPs = ["11.1.0.12/32"];
        }
      ];
    };
  };
}
