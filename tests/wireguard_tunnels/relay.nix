_: {
  lib,
  pkgs,
  test_wireguard_keys,
  ...
}: let
  read_key = name: lib.removeSuffix "\n" (builtins.readFile "${test_wireguard_keys}/${name}");

  shared_vlan_ipv4 = "192.0.2.1";
  shared_vlan_ipv6 = "fd00:1::1";
  wireguard_host_ipv4 = "11.1.0.1";
  wireguard_host_ipv6 = "fd11:1::1";
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
      ${pkgs.coreutils}/bin/install -Dm400 ${test_wireguard_keys}/relay.private /run/secrets/wg_main_priv
    '';
  };

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
    allowedTCPPorts = [18080 18084];
    allowedUDPPorts = [18082 18084];
    allowPing = true;
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
    curl
    iproute2
    socat
    netcat-openbsd
    python3
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
          private_ip_v6 = "fd11:1::11";
          public_key = read_key "isolated-host.public";
        };
        forward = [
          {
            port_in = 18080;
            port_out = 18080;
            protocol = "tcp";
          }
          {
            port_in = 18082;
            port_out = 18082;
            protocol = "udp";
          }
          {
            port_in = 18084;
            port_out = 18084;
            protocol = "both";
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
            ip = wireguard_host_ipv4;
            mask = "24";
          };
          subnet_v6 = {
            ip = wireguard_host_ipv6;
            mask = "64";
          };
        };
      };
      extra_peers = [
        {
          publicKey = read_key "isolated-namespace.public";
          allowedIPs = [
            "11.1.0.12/32"
            "fd11:1::12/128"
          ];
        }
      ];
    };
  };
}
