{
  mylib,
  lib,
  pkgs,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  inherit (o) t;

  WireguardPeer = t.submodule (_: {
    options = {
      publicKey = t.optional t.str {};
      allowedIPs = t.optional "Peer allowed IP submasks" (t.listOf t.str) {};
    };
  });

  ForwardPortRule = t.submodule (_: {
    options = {
      port_in = o.opt "External port to listen on" t.int null;
      port_out = o.opt "Internal port to forward to" t.int null;
    };
  });
in
  # [!!!] This is for the `server` impl. of wireguard
  # and by default, it will allow *inbound* traffic, acting as a relay
  # like ngrok and such
  o.module "unit.wireguard" (with o; {
    enable = toggle "Enable Wireguard" false;
    relay = {
      enable = toggle "Act as a relay for client traffic" true;
      public_ip = opt "Public IP for server relaying traffic" t.str null;
      peer = {
        public_key = optional "Public key for peer" t.str {};
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
    interfaces = {
      external.name = opt "External interface name" t.str "eth0";
      internal = {
        name = opt "Internal interface name" t.str "wg0";
        subnet = {
          ip = opt "Subnet mask for internal interface (IP part)" t.str "11.1.0.0";
          mask = opt "Subnet mask for internal interface (mask part)" t.str "24";
        };
        listen_port = opt "Port for wireguard connections" t.int 51820;
      };
    };
  }) {} (opts: (o.when opts.enable (let
    main_pub_key = lib.readFile (s.secret_path "wg_main_pub");
  in
    o.merge [
      {
        sops.secrets = {
          "wg_main_pub" = s.mk_secret "${s.dir}/wireguard/main.yaml" "key_pub" {};
          "wg_main_priv" = s.mk_secret "${s.dir}/wireguard/main.yaml" "key_priv" {};
        };
      }
      (o.when opts.relay.enable (let
        peer_pub_key =
          if opts.relay.peer.public_key
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
      {
        networking = with opts.interfaces; {
          firewall = {
            allowedUDPPorts = [internal.listen_port];
          };
          nat = {
            enable = true;
            externalInterface = external.name;
            internalInterfaces = internal.name;
          };
          wireguard.interfaces.${internal.name} = {
            ips = ["${internal.subnet.ip}/${internal.subnet.mask}"];
            listenPort = internal.listen_port;
            privateKeyFile = s.secret_path "wg_main_priv";
            peers = opts.extra_peers;
          };
        };
      }
    ])))
