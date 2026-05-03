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

  Protocol = t.enum ["tcp" "udp" "both"];
  IPFamily = t.enum ["ipv4" "ipv6"];

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
      protocol = o.opt "Protocol (tcp/udp/both)" Protocol "tcp";
    };
  });

  PortMapping = t.submodule (_: {
    options = {
      from = o.opt "Port on host" t.int null;
      to = o.opt "Port in VPN namespace" t.int null;
      protocol = o.opt "Protocol" Protocol "tcp";
    };
  });

  VPNPort = t.submodule (_: {
    options = {
      port = o.opt "Port number" t.int null;
      protocol = o.opt "Protocol (tcp/udp/both)" Protocol "both";
    };
  });

  BlockedDoHEndpoint = t.submodule (_: {
    options = {
      family = o.opt "Address family for the blocked endpoint" IPFamily "ipv4";
      address = o.opt "Blocked endpoint address" t.str null;
      port = o.opt "Blocked endpoint port" t.int null;
    };
  });
in
  o.module "unit.wireguard" (with o; {
    enable = toggle "Enable Wireguard" false;
    relay = {
      enable = toggle "Act as a relay for client traffic" true;
      peer = {
        public_key = opt "Public key for peer" t.str main_pub_key;
        private_ip = opt "IP for peer in subnet" t.str "11.1.0.11";
        private_ip_v6 = optional "IPv6 for peer in subnet" t.str {};
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
        privateKeyFile = optional "Override private key file for this interface" t.str {};
        subnet = {
          ip = opt "Subnet mask for internal interface (IP part)" t.str "11.1.0.0";
          mask = opt "Subnet mask for internal interface (mask part)" t.str "24";
        };
        subnet_v6 = {
          ip = optional "IPv6 subnet for internal interface (IP part)" t.str {};
          mask = optional "IPv6 subnet for internal interface (mask part)" t.str {};
        };
        listen_port = opt "Port for wireguard connections" t.int 51820;
      };
    };
    client = {
      enable = toggle "Enable VPN client namespace" false;
      namespace = opt "Namespace name (max 7 chars)" t.str "wg";
      address = opt "WireGuard address in namespace" t.str "11.1.0.12/32";
      address_v6 = optional "WireGuard IPv6 address in namespace" t.str {};
      dns = opt "DNS server(s) for namespace" (t.oneOf [t.str (t.listOf t.str)]) "192.168.15.5";
      endpoint = opt "Server endpoint (ip:port)" t.str null;
      server_public_key = opt "Server's public key" t.str main_pub_key;
      persistent_keepalive = opt "Keepalive interval (seconds)" t.int 25;
      accessible_from = opt "Subnets that can access namespace" (t.listOf t.str) [
        "192.168.15.0/24"
        "127.0.0.1"
      ];
      bridge_address = opt "IPv4 bridge address on the default namespace" t.str "10.15.0.5";
      namespace_address = opt "IPv4 address exposed by the namespace bridge" t.str "10.15.0.1";
      bridge_address_v6 = opt "IPv6 bridge address on the default namespace" t.str "fd93:9701:1d00::1";
      namespace_address_v6 = opt "IPv6 address exposed by the namespace bridge" t.str "fd93:9701:1d00::2";
      strict_dns = {
        enable = toggle "Reject non-approved DNS egress from the namespace" true;
        block_doh_endpoints = opt "Explicit DNS-over-HTTPS endpoints to block" (t.listOf BlockedDoHEndpoint) [];
      };
      confined_services = opt "Services to confine to VPN" (t.listOf t.str) [];
      port_mappings = opt "Port mappings host->namespace" (t.listOf PortMapping) [];
      open_vpn_ports = opt "Ports open through VPN" (t.listOf VPNPort) [];
    };
  }) {imports = _: [../network_namespaces];} (opts: let
    protocols_for = protocol:
      if protocol == "both"
      then ["tcp" "udp"]
      else [protocol];

    dns_servers =
      if builtins.isList opts.client.dns
      then opts.client.dns
      else [opts.client.dns];

    client_addresses = [opts.client.address] ++ lib.optionals (opts.client.address_v6 != null) [opts.client.address_v6];
    client_allowed_ips = ["0.0.0.0/0"] ++ lib.optionals (opts.client.address_v6 != null) ["::/0"];

    relay_forward_ports_for = wanted_protocol:
      lib.unique (
        lib.concatMap (
          rule:
            lib.optionals (builtins.elem wanted_protocol (protocols_for rule.protocol)) [rule.port_in]
        )
        opts.relay.forward
      );

    relay_allowed_tcp_ports = lib.optionals opts.relay.enable (relay_forward_ports_for "tcp");
    relay_allowed_udp_ports =
      [opts.interfaces.internal.listen_port]
      ++ lib.optionals opts.relay.enable (relay_forward_ports_for "udp");

    has_internal_ipv6 =
      opts.interfaces.internal.subnet_v6.ip
      != null
      && opts.interfaces.internal.subnet_v6.mask != null;
    has_relay_ipv6 = opts.relay.peer.private_ip_v6 != null && has_internal_ipv6;

    wg_conf_gen = pkgs.writeShellScript "gen-wg-vpn-conf" ''
      mkdir -p /run/wireguard
      cat > /run/wireguard/vpn.conf <<WGEOF
      [Interface]
      PrivateKey = $(cat ${s.secret_path "wg_vpn_priv"})
      Address = ${lib.concatStringsSep ", " client_addresses}
      DNS = ${lib.concatStringsSep ", " dns_servers}

      [Peer]
      PublicKey = ${opts.client.server_public_key}
      Endpoint = ${opts.client.endpoint}
      AllowedIPs = ${lib.concatStringsSep ", " client_allowed_ips}
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

          ipt = "${pkgs.iptables}/bin/iptables";
          ip6t = "${pkgs.iptables}/bin/ip6tables";

          forward_port_rules = tool: is_ipv6: destination: source: action: rule: let
            _in = toString rule.port_in;
            _out = toString rule.port_out;
            formatted_destination =
              if is_ipv6
              then "[${destination}]:${_out}"
              else "${destination}:${_out}";
          in
            lib.concatMapStrings (protocol: ''
              ${tool} -t nat ${action} PREROUTING -i $ETH_INTERFACE -p ${protocol} --dport ${_in} -j DNAT --to-destination ${formatted_destination}
              ${tool} -t nat ${action} POSTROUTING -o $WG_INTERFACE -p ${protocol} --dport ${_out} -d ${destination} -j SNAT --to-source ${source}
              ${tool} ${action} FORWARD -i $ETH_INTERFACE -o $WG_INTERFACE -p ${protocol} --dport ${_out} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
              ${tool} ${action} FORWARD -i $WG_INTERFACE -o $ETH_INTERFACE -p ${protocol} --sport ${_out} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
            '') (protocols_for rule.protocol);

          ipt_common = ''
            ETH_INTERFACE=${opts.interfaces.external.name}
            WG_INTERFACE=${opts.interfaces.internal.name}
            WG_LAN_HOST=${opts.interfaces.internal.subnet.ip}
            WG_LAN_PEER=${opts.relay.peer.private_ip}
          '';

          ip6t_common = lib.optionalString has_relay_ipv6 ''
            WG_LAN_HOST_V6=${opts.interfaces.internal.subnet_v6.ip}
            WG_LAN_PEER_V6=${opts.relay.peer.private_ip_v6}
          '';

          ipt_up = ''
            ${ipt_common}
            ${ip6t_common}
            ${lib.concatMapStrings (forward_port_rules ipt false "$WG_LAN_PEER" "$WG_LAN_HOST" "-A") opts.relay.forward}
            ${lib.optionalString has_relay_ipv6 (lib.concatMapStrings (forward_port_rules ip6t true "$WG_LAN_PEER_V6" "$WG_LAN_HOST_V6" "-A") opts.relay.forward)}
          '';

          ipt_down = ''
            ${ipt_common}
            ${ip6t_common}
            ${lib.optionalString has_relay_ipv6 (lib.concatMapStrings (forward_port_rules ip6t true "$WG_LAN_PEER_V6" "$WG_LAN_HOST_V6" "-D") (lib.reverseList opts.relay.forward))}
            ${lib.concatMapStrings (forward_port_rules ipt false "$WG_LAN_PEER" "$WG_LAN_HOST" "-D") (lib.reverseList opts.relay.forward)}
          '';
        in {
          boot.kernel.sysctl =
            {
              "net.ipv4.ip_forward" = 1;
            }
            // lib.optionalAttrs has_relay_ipv6 {
              "net.ipv6.conf.all.forwarding" = 1;
            };

          networking.wireguard.interfaces.${opts.interfaces.internal.name} = {
            peers = [
              {
                publicKey = peer_pub_key;
                allowedIPs = ["${opts.relay.peer.private_ip}/32"] ++ lib.optionals (opts.relay.peer.private_ip_v6 != null) ["${opts.relay.peer.private_ip_v6}/128"];
              }
            ];

            postSetup = ipt_up;

            postShutdown = ipt_down;
          };
        }))
        (o.when opts.nat.enable {
          networking = with opts.interfaces; let
            external_interface = assert (external.name != null); external.name;
            ip6t = "${pkgs.iptables}/bin/ip6tables";
            internal_subnet_v6 = "${internal.subnet_v6.ip}/${internal.subnet_v6.mask}";
          in {
            nat = {
              enable = true;
              externalInterface = external_interface;
              internalInterfaces = [internal.name];
            };

            wireguard.interfaces.${internal.name} = lib.optionalAttrs has_internal_ipv6 {
              postSetup = lib.mkAfter ''
                ${ip6t} -A FORWARD -i ${internal.name} -o ${external_interface} -s ${internal_subnet_v6} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
                ${ip6t} -A FORWARD -i ${external_interface} -o ${internal.name} -d ${internal_subnet_v6} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                ${ip6t} -t nat -A POSTROUTING -o ${external_interface} -s ${internal_subnet_v6} -j MASQUERADE
              '';
              postShutdown = lib.mkBefore ''
                ${ip6t} -t nat -D POSTROUTING -o ${external_interface} -s ${internal_subnet_v6} -j MASQUERADE
                ${ip6t} -D FORWARD -i ${external_interface} -o ${internal.name} -d ${internal_subnet_v6} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                ${ip6t} -D FORWARD -i ${internal.name} -o ${external_interface} -s ${internal_subnet_v6} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
              '';
            };
          };
        })
        {
          networking = with opts.interfaces; {
            firewall = {
              allowedTCPPorts = relay_allowed_tcp_ports;
              allowedUDPPorts = lib.unique relay_allowed_udp_ports;
            };
            wireguard.interfaces.${internal.name} = {
              ips =
                ["${internal.subnet.ip}/${internal.subnet.mask}"]
                ++ lib.optionals has_internal_ipv6 ["${internal.subnet_v6.ip}/${internal.subnet_v6.mask}"];
              listenPort = internal.listen_port;
              privateKeyFile =
                if internal.privateKeyFile != null && internal.privateKeyFile != ""
                then s.secret_path internal.privateKeyFile
                else s.secret_path "wg_main_priv";
              peers = opts.extra_peers;
            };
          };
        }
        (o.when opts.client.enable (
          o.merge [
            {
              sops.secrets = {
                "wg_vpn_priv" = s.mk_secret "${s.dir}/wireguard/vpn.yaml" "key_priv" {};
              };
            }
            {
              networking.firewall.checkReversePath = "loose";

              my.network_namespaces.${opts.client.namespace} = {
                enable = true;
                backend = {
                  type = "wireguard";
                  wireguard.config_file = "/run/wireguard/vpn.conf";
                };
                addresses = {
                  host_v4 = opts.client.bridge_address;
                  namespace_v4 = opts.client.namespace_address;
                  host_v6 = opts.client.bridge_address_v6;
                  namespace_v6 = opts.client.namespace_address_v6;
                };
                dns = {
                  servers = dns_servers;
                  strict = opts.client.strict_dns;
                };
                services = opts.client.confined_services;
                inherit (opts.client) accessible_from;
                inherit (opts.client) port_mappings;
                inherit (opts.client) open_vpn_ports;
              };

              systemd.services.${opts.client.namespace}.serviceConfig.ExecStartPre = lib.mkBefore [
                "+${wg_conf_gen}"
              ];
            }
          ]
        ))
      ]
    ))
