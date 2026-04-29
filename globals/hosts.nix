let
  default_ssh_port = 59222;
in rec {
  lavpc = {
    hostname = "lavpc";
    host_ip = "192.168.15.2";
    ssh_user = "lav";
    ssh_port = default_ssh_port;
    config = {
      my = {
        desktop.enable = true;
        storage.client.enable = true;
        storage.client.server = tyrant.hostname;
        host.password.sops_key = "main";

        "unit.backup" = {
          enable = true;
          coordinator_host = "tyrant";
          destinations = {
            A = {
              enable = true;
              backend = "sftp";
              repository_template = "sftp://tyrant@${tyrant.host_ip}:59222//var/lib/backups/repos/{host}";
            };
            B.enable = false;
            C.enable = false;
          };
        };
        syncthing = {
          server_device_id = "AG4H3VD-YDLADHK-Z7KLFFD-K2IQIUE-DRIY2IW-XDLZAKW-RW6ZQPV-26LF5AF";
        };
      };
    };
  };

  tyrant = {
    hostname = "192.168.15.13";
    host_ip = "192.168.15.13";
    ssh_user = "tyrant";
    ssh_port = default_ssh_port;
    config = let
      interface_name = "enp3s0f1";
    in {
      my = {
        server.enable = true;
        storage.server.enable = true;
        storage.server.allowed_clients = [lavpc.host_ip];
        host.password.sops_key = "server";
        "unit.octodns" = {
          enable = true;
        };

        "unit.hister" = {
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

        "unit.postgres" = {
          enable = true;
        };

        "unit.kaneo" = {
          enable = true;
        };

        "unit.qbittorrent" = {
          enable = true;
        };

        "unit.forgejo" = {
          enable = true;
        };
        "unit.syncthing" = {
          enable = true;
          peer_device_ids.lavpc = "S7TNWPT-Q35KRUD-Q6SHKYK-REO2WLZ-DMLV7TW-KYPFCXJ-BFVECBC-LTRVHQT";
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
              repository_template = "sftp://${temperance.ssh_user}@${temperance.hostname}:59222//var/lib/backups/repos/{host}";
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
            shared_docs_core = {
              kind = "path";
              policy = "sensitive_data";
              path.paths = ["/srv/shared/docs/core"];
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
            dns = tyrant.host_ip;
            endpoint = with temperance; "${hostname}:51820";
            # confined_services = ["transmission"];
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
  temperance = {
    hostname = "89.167.107.74";
    host_ip = "89.167.107.74";
    ssh_user = "temperance";
    ssh_port = default_ssh_port;
    config = {
      my = {
        server.enable = true;
        host.password.sops_key = "server";
        "unit.wireguard" = {
          enable = true;
          relay = {
            enable = true;
            public_ip = temperance.host_ip;
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
