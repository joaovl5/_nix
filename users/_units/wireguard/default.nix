{
  mylib,
  lib,
  pkgs,
  config,
  ...
} @ args: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  inherit (o) t;

  public_data = import ../../../_modules/public.nix args;

  main_pub_key = public_data.wireguard_key;

  WireguardPeer = t.submodule (_: {
    options = {
      publicKey = o.opt "Public key for peer" t.str main_pub_key;
      allowedIPs = o.optional "Peer allowed IP submasks" (t.listOf t.str) {};
      endpoint = o.optional "Peer conn. endpoint, if applicable" t.str {};
      persistentKeepalive = o.optional "Set to send keep-alives at every N seconds" t.int {};
    };
  });

  ForwardPortRule = t.submodule (_: {
    options = {
      port_in = o.opt "External port to listen on" t.int null;
      port_out = o.opt "Internal port to forward to" t.int null;
    };
  });

  PortMapping = t.submodule (_: {
    options = {
      from = o.opt "Port on host" t.int null;
      to = o.opt "Port in VPN namespace" t.int null;
      protocol = o.opt "Protocol" t.str "tcp";
    };
  });

  VPNPort = t.submodule (_: {
    options = {
      port = o.opt "Port number" t.int null;
      protocol = o.opt "Protocol (tcp/udp/both)" t.str "both";
    };
  });
in
  o.module "unit.wireguard" (with o; {
    enable = toggle "Enable Wireguard" false;
    relay = {
      enable = toggle "Act as a relay for client traffic" true;
      public_ip = opt "Public IP for server relaying traffic" t.str null;
      peer = {
        public_key = opt "Public key for peer" t.str main_pub_key;
        private_ip = opt "IP for peer in subnet" t.str "11.1.0.11";
      };
      forward = opt "Port forwarding rules" (t.listOf ForwardPortRule) [
        {
          port_in = 80;
          port_out = 80;
        }
        {
          port_in = 443;
          port_out = 443;
        }
      ];
    };
    extra_peers = opt "Extra peers data" (t.listOf WireguardPeer) [];
    nat.enable = toggle "Enable NAT (wireguard server)" true;
    interfaces = {
      external.name = optional "External interface name" t.str {};
      internal = {
        name = opt "Internal interface name" t.str "wg0";
        subnet = {
          ip = opt "Subnet mask for internal interface (IP part)" t.str "11.1.0.0";
          mask = opt "Subnet mask for internal interface (mask part)" t.str "24";
        };
        listen_port = opt "Port for wireguard connections" t.int 51820;
      };
    };
    client = {
      enable = toggle "Enable VPN client namespace" false;
      namespace = opt "Namespace name (max 7 chars)" t.str "wg";
      address = opt "WireGuard address in namespace" t.str "11.1.0.12/32";
      dns = opt "DNS server for namespace" t.str "192.168.15.5";
      endpoint = opt "Server endpoint (ip:port)" t.str null;
      server_public_key = opt "Server's public key" t.str main_pub_key;
      persistent_keepalive = opt "Keepalive interval (seconds)" t.int 25;
      accessible_from = opt "Subnets that can access namespace" (t.listOf t.str) [
        "192.168.15.0/24"
        "127.0.0.1"
      ];
      confined_services = opt "Services to confine to VPN" (t.listOf t.str) [];
      port_mappings = opt "Port mappings host->namespace" (t.listOf PortMapping) [];
      open_vpn_ports = opt "Ports open through VPN" (t.listOf VPNPort) [];
    };
  }) {} (opts: let
    wg_conf_gen = pkgs.writeShellScript "gen-wg-vpn-conf" ''
      mkdir -p /run/wireguard
      cat > /run/wireguard/vpn.conf <<WGEOF
      [Interface]
      PrivateKey = $(cat ${s.secret_path "wg_vpn_priv"})
      Address = ${opts.client.address}
      DNS = ${opts.client.dns}

      [Peer]
      PublicKey = ${opts.client.server_public_key}
      Endpoint = ${opts.client.endpoint}
      AllowedIPs = 0.0.0.0/0
      PersistentKeepalive = ${toString opts.client.persistent_keepalive}
      WGEOF
      chmod 600 /run/wireguard/vpn.conf
    '';
  in
    o.when opts.enable (
      o.merge [
        {
          sops.secrets = {
            "wg_main_pub" = s.mk_secret "${s.dir}/wireguard/main.yaml" "key_pub" {};
            "wg_main_priv" = s.mk_secret "${s.dir}/wireguard/main.yaml" "key_priv" {};
            "wg_tyrant_priv" = s.mk_secret "${s.dir}/wireguard/tyrant.yaml" "key_priv" {};
          };
        }
        (o.when opts.relay.enable (let
          peer_pub_key =
            if opts.relay.peer.public_key != null
            then opts.relay.peer.public_key
            else main_pub_key;

          # todo migrate to nftables/other
          ipt = lib.getExe pkgs.iptables;

          ipt_forward_port = action: rule: let
            _in = toString rule.port_in;
            _out = toString rule.port_out;
          in ''
            ${ipt} -t nat ${action} PREROUTING -i $ETH_INTERFACE -p tcp --dport ${_in} -j DNAT --to-destination $WG_LAN_PEER:${_out}
            ${ipt} -t nat ${action} POSTROUTING -o $WG_INTERFACE -p tcp --dport ${_out} -d $WG_LAN_PEER -j SNAT --to-source $WG_LAN_HOST
            ${ipt} ${action} FORWARD -i $ETH_INTERFACE -o $WG_INTERFACE -p tcp --dport ${_out} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
            ${ipt} ${action} FORWARD -i $WG_INTERFACE -o $ETH_INTERFACE -p tcp --sport ${_out} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          '';

          ipt_common = ''
            ETH_INTERFACE=${opts.interfaces.external.name}
            WG_INTERFACE=${opts.interfaces.internal.name}
            WG_LAN_HOST=${opts.interfaces.internal.subnet.ip}
            WG_LAN_PEER=${opts.relay.peer.private_ip}
          '';

          ipt_up = ''
            ${ipt_common}
            ${lib.concatMapStrings (ipt_forward_port "-A") opts.relay.forward}
          '';

          ipt_down = ''
            ${ipt_common}
            ${lib.concatMapStrings (ipt_forward_port "-D") (lib.reverseList opts.relay.forward)}
          '';
        in {
          boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
          networking.wireguard.interfaces.${opts.interfaces.internal.name} = {
            peers = [
              {
                publicKey = peer_pub_key;
                allowedIPs = ["${opts.relay.peer.private_ip}/32"];
              }
            ];

            postSetup = ipt_up;

            postShutdown = ipt_down;
          };
        }))
        (o.when opts.nat.enable {
          networking = with opts.interfaces; let
            external_interface = assert (external.name != null); external.name;
          in {
            nat = {
              enable = true;
              externalInterface = external_interface;
              internalInterfaces = [internal.name];
            };
          };
        })
        {
          networking = with opts.interfaces; {
            firewall = {
              allowedUDPPorts = [internal.listen_port];
            };
            wireguard.interfaces.${internal.name} = {
              ips = ["${internal.subnet.ip}/${internal.subnet.mask}"];
              listenPort = internal.listen_port;
              privateKeyFile = s.secret_path "wg_main_priv";
              peers = opts.extra_peers;
            };
          };
        }
        (o.when opts.client.enable (o.merge [
          {
            sops.secrets = {
              "wg_vpn_priv" = s.mk_secret "${s.dir}/wireguard/vpn.yaml" "key_priv" {};
            };
          }
          {
            networking.firewall.checkReversePath = "loose";

            vpnNamespaces.${opts.client.namespace} = {
              enable = true;
              wireguardConfigFile = "/run/wireguard/vpn.conf";
              accessibleFrom = opts.client.accessible_from;
              bridgeAddress = "10.15.0.5";
              namespaceAddress = "10.15.0.1";
              portMappings = opts.client.port_mappings;
              openVPNPorts = opts.client.open_vpn_ports;
            };

            systemd.services.${opts.client.namespace}.serviceConfig.ExecStartPre = lib.mkBefore [
              "+${wg_conf_gen}"
            ];
          }
          {
            systemd.services = builtins.listToAttrs (map (svc: {
                name = svc;
                value.vpnConfinement = {
                  enable = true;
                  vpnNamespace = opts.client.namespace;
                };
              })
              opts.client.confined_services);
          }
        ]))
      ]
    ))
