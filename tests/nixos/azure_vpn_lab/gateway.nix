_: {
  config,
  pkgs,
  azure_vpn_lab,
  test_azure_vpn_material,
  ...
}: let
  cfg = azure_vpn_lab;
  strongswan = config.services.strongswan-swanctl.package;
in {
  imports = [
    ../../common/base_node.nix
    (import ../../../modules/aspects/base/options.nix {}).den.aspects.base-options.nixos
  ];

  system.stateVersion = "25.11";

  my.nix.hostname = "azure-vpn-gateway";
  my.nix.username = "tester";

  virtualisation.vlans = [1 2];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.interfaces = {
    eth1 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = cfg.public.gateway_ipv4;
          prefixLength = cfg.public.prefix_length;
        }
      ];
    };

    eth2 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = cfg.private.gateway_ipv4;
          prefixLength = cfg.private.prefix_length;
        }
      ];
    };
  };

  networking.firewall = {
    allowedUDPPorts = [500 4500];
    checkReversePath = false;
    extraCommands = ''
      iptables --insert INPUT --protocol esp --jump ACCEPT
      iptables --insert FORWARD --source ${cfg.p2s_pool_cidr} --destination ${cfg.private.subnet_cidr} --jump ACCEPT
      iptables --insert FORWARD --source ${cfg.private.subnet_cidr} --destination ${cfg.p2s_pool_cidr} --jump ACCEPT
    '';
    extraStopCommands = ''
      iptables --delete INPUT --protocol esp --jump ACCEPT || true
      iptables --delete FORWARD --source ${cfg.p2s_pool_cidr} --destination ${cfg.private.subnet_cidr} --jump ACCEPT || true
      iptables --delete FORWARD --source ${cfg.private.subnet_cidr} --destination ${cfg.p2s_pool_cidr} --jump ACCEPT || true
    '';
  };

  environment.systemPackages = with pkgs; [
    curl
    iproute2
    strongswan
  ];

  environment.etc = {
    "swanctl/x509ca/azure-vpn-test-ca.pem".source = "${test_azure_vpn_material}/ca.pem";
    "swanctl/x509/gateway.pem".source = "${test_azure_vpn_material}/gateway.pem";
    "swanctl/private/gateway-key.pem" = {
      source = "${test_azure_vpn_material}/gateway-key.pem";
      mode = "0400";
    };
  };

  services.strongswan-swanctl = {
    enable = true;
    swanctl = {
      pools.p2s = {
        addrs = cfg.p2s_pool_cidr;
        split_include = [cfg.private.subnet_cidr];
      };

      connections.azure-p2s = {
        version = 2;
        local_addrs = [cfg.public.gateway_ipv4];
        remote_addrs = ["%any"];
        proposals = cfg.ike_proposals;
        pools = ["p2s"];
        send_cert = "always";

        local.main = {
          auth = "pubkey";
          id = cfg.gateway_fqdn;
          certs = ["gateway.pem"];
        };

        remote.main = {
          auth = "pubkey";
          id = cfg.client_id;
          cacerts = ["azure-vpn-test-ca.pem"];
        };

        children.azure-vnet = {
          local_ts = [cfg.private.subnet_cidr];
          remote_ts = ["dynamic"];
          inherit (cfg) esp_proposals;
          updown = "${strongswan}/libexec/ipsec/_updown iptables";
        };
      };
    };
  };
}
