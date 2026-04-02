rec {
  tyrant = {
    hostname = "192.168.15.13";
    ssh_user = "tyrant";
    config = let
      interface_name = "enp3s0f1";
    in {
      my = {
        "unit.octodns" = {
          enable = true;
        };

        "unit.traefik" = {
          enable = true;
        };

        "unit.pihole" = {
          enable = true;
          dns = {
            interface = interface_name;
          };
        };

        "unit.soularr" = {
          enable = true;
        };

        "unit.fxsync" = {
          enable = true;
        };

        "unit.nixarr" = {
          enable = true;
          vpn.enable = false; # our wireguard unit handles VPN
        };

        "unit.actual-budget" = {
          enable = true;
        };

        "unit.qbittorrent" = {
          enable = true;
        };

        # host tunnel (inbound relay)
        "unit.wireguard" = {
          enable = true;
          relay.enable = false;
          nat.enable = false;
          interfaces.internal = {
            name = "wg-host";
            privateKeyFile = "wg_tyrant_priv";
            subnet = {
              ip = "11.1.0.11";
              mask = "32";
            };
          };
          extra_peers = [
            {
              allowedIPs = ["11.1.0.0/24"];
              endpoint = with temperance; "${hostname}:51820";
              persistentKeepalive = 25;
            }
          ];
          # VPN namespace for confined services (outbound VPN)
          client = {
            enable = true;
            address = "11.1.0.12/32";
            dns = "192.168.15.13";
            endpoint = with temperance; "${hostname}:51820";
            confined_services = ["transmission"];
            port_mappings = [
              {
                from = 9091;
                to = 9091;
              }
            ];
            open_vpn_ports = [
              {
                port = 55055;
                protocol = "both";
              }
            ];
          };
        };
      };
    };
  };
  temperance = let
    hostname = "89.167.107.74";
  in {
    inherit hostname;
    ssh_user = "temperance";
    config = {
      my = {
        "unit.wireguard" = {
          enable = true;
          relay = {
            enable = true;
            public_ip = hostname;
            peer.private_ip = tyrant.config.my."unit.wireguard".interfaces.internal.subnet.ip;
          };
          interfaces.external.name = "enp1s0";
          extra_peers = [
            {
              publicKey = "Ex/dhc5AoC7VNe1jIu5rISwQnRoJ7JcbW2M43GJvnTY=";
              allowedIPs = ["11.1.0.12/32"];
            }
          ];
        };
      };
    };
  };
}
