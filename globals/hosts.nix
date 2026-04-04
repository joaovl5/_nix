rec {
  lavpc = {
    hostname = "lavpc";
    ssh_user = "lav";
    config = {
      my = {
        "unit.backup" = {
          enable = true;
          coordinator_host = "tyrant";
          destinations = {
            A = {
              enable = true;
              backend = "sftp";
              repository_template = "sftp:tyrant@192.168.15.13:/var/lib/backups/repos/{host}";
            };
            B.enable = false;
            C.enable = false;
          };
          host_items.shared_sync = {
            kind = "path";
            policy = "sensitive_data";
            path.paths = ["/home/lav/.sensitive"];
          };
        };
      };
    };
  };

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

        "unit.backup" = {
          enable = true;
          coordinator_host = "tyrant";
          destinations = {
            A = {
              enable = true;
              backend = "filesystem";
              repository_template = "/var/lib/backups/repos/{host}";
            };
            B = {
              enable = true;
              backend = "sftp";
              repository_template = "sftp:${temperance.ssh_user}@${temperance.hostname}:/var/lib/backups/repos/{host}";
            };
            C.enable = false;
          };
          host_items = {
            home_snapshot = {
              kind = "path";
              policy = "filesystem_snapshot";
              promote_to = ["B"];
              path = {
                paths = ["/home/tyrant"];
                exclude = [
                  "/home/tyrant/private/units/soularr/data"
                  "/home/tyrant/.local/share/docker"
                ];
              };
            };
          };
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
