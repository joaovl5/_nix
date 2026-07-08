_: {
  den.aspects.desktop.nixos = {
    config,
    lib,
    mylib,
    pkgs,
    ...
  }: let
    my = mylib.use config;
    o = my.options;
    s = my.secrets;
    inherit (o) t;

    default_sops_file = "${s.dir}/work/azure-vpn.yaml";

    secret_path = name: s.secret_path name;
  in
    o.module "azure-vpn" (with o; {
      enable = toggle "Enable Azure VPN IKEv2 client" false;
      package = opt "strongSwan package used for the Azure VPN client" t.package pkgs.strongswan;

      secrets = {
        sops_file = opt "Azure VPN settings/credentials" t.str default_sops_file;
        gateway_fqdn_key = opt "Azure VPN gateway FQDN" t.str "gateway_fqdn";
        remote_id_key = opt "Remote IKE identity" t.str "remote_id";
        client_id_key = opt "Local/client IKE identity" t.str "client_id";
        remote_ts_key = opt "Comma-separated protected traffic selectors" t.str "remote_ts";
        ca_cert_key = opt "Trusted CA certificate" t.str "ca_cert";
        client_cert_key = opt "Client certificate" t.str "client_cert";
        client_key_key = opt "Client private key" t.str "client_key";
      };

      connection = {
        name = opt "swanctl connection name" t.str "azure-p2s";
        child_name = opt "swanctl child SA name" t.str "azure-vnet";
        ike_proposals = opt "IKE proposals offered to Azure VPN" (t.listOf t.str) [
          "aes256gcm16-prfsha384-ecp384"
          "aes256gcm16-prfsha384-modp2048"
        ];
        esp_proposals = opt "ESP proposals offered to Azure VPN" (t.listOf t.str) ["aes256gcm16"];
        start_action = opt "strongSwan child start action; use 'none' for manual toggling, or 'trap' for on-demand policy" (t.enum ["none" "start" "trap"]) "start";
      };

      runtime = {
        dir = opt "Runtime directory for rendered Azure VPN swanctl files" t.str "/run/azure-vpn";
      };
    }) {} (opts: let
      runtime_dir = opts.runtime.dir;
      include_file = "${runtime_dir}/swanctl.conf";
      ca_cert_path = "/etc/swanctl/x509ca/azure-vpn-ca.pem";
      client_cert_path = "/etc/swanctl/x509/azure-vpn-client.pem";
      client_key_path = "/etc/swanctl/private/azure-vpn-client-key.pem";

      gateway_fqdn_secret = "azure_vpn_gateway_fqdn";
      remote_id_secret = "azure_vpn_remote_id";
      client_id_secret = "azure_vpn_client_id";
      remote_ts_secret = "azure_vpn_remote_ts";
      ca_cert_secret = "azure_vpn_ca_cert";
      client_cert_secret = "azure_vpn_client_cert";
      client_key_secret = "azure_vpn_client_key";

      proposals = lib.concatStringsSep ", " opts.connection.ike_proposals;
      esp_proposals = lib.concatStringsSep ", " opts.connection.esp_proposals;

      render_swanctl = pkgs.writeShellScript "render-azure-vpn-swanctl" ''
        set -euo pipefail
        umask 077

        install -d -m 0700 ${runtime_dir}
        install -d -m 0755 /etc/swanctl/x509ca /etc/swanctl/x509
        install -d -m 0700 /etc/swanctl/private

        install -m 0400 ${secret_path ca_cert_secret} ${ca_cert_path}
        install -m 0400 ${secret_path client_cert_secret} ${client_cert_path}
        install -m 0400 ${secret_path client_key_secret} ${client_key_path}

        read_secret() {
          ${pkgs.coreutils}/bin/tr -d '\r\n' < "$1"
        }

        gateway_fqdn="$(read_secret ${secret_path gateway_fqdn_secret})"
        remote_id="$(read_secret ${secret_path remote_id_secret})"
        client_id="$(read_secret ${secret_path client_id_secret})"
        remote_ts="$(${pkgs.coreutils}/bin/tr '\n' ',' < ${secret_path remote_ts_secret} \
          | ${pkgs.gnused}/bin/sed -e 's/[[:space:]]//g' -e 's/,,*/,/g' -e 's/^,//' -e 's/,$//')"

        if [ -z "$gateway_fqdn" ] || [ -z "$remote_id" ] || [ -z "$client_id" ] || [ -z "$remote_ts" ]; then
          echo "Azure VPN SOPS secrets rendered an incomplete swanctl configuration" >&2
          exit 1
        fi

        cat > ${include_file} <<SWANCTL
        connections {
          ${opts.connection.name} {
            version = 2
            remote_addrs = $gateway_fqdn
            proposals = ${proposals}
            vips = 0.0.0.0
            keyingtries = 0
            send_cert = always

            local {
              auth = pubkey
              id = $client_id
              certs = ${client_cert_path}
            }

            remote {
              auth = pubkey
              id = $remote_id
              cacerts = ${ca_cert_path}
            }

            children {
              ${opts.connection.child_name} {
                local_ts = dynamic
                remote_ts = $remote_ts
                esp_proposals = ${esp_proposals}
                start_action = ${opts.connection.start_action}
                updown = ${opts.package}/libexec/ipsec/_updown iptables
              }
            }
          }
        }
        SWANCTL
        chmod 0600 ${include_file}
      '';
    in
      o.when opts.enable {
        sops.secrets = {
          ${gateway_fqdn_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.gateway_fqdn_key {};
          ${remote_id_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.remote_id_key {};
          ${client_id_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.client_id_key {};
          ${remote_ts_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.remote_ts_key {};
          ${ca_cert_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.ca_cert_key {};
          ${client_cert_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.client_cert_key {};
          ${client_key_secret} = s.mk_secret opts.secrets.sops_file opts.secrets.client_key_key {};
        };

        services.strongswan-swanctl = {
          enable = true;
          inherit (opts) package;
          includes = [include_file];
        };

        systemd.services.strongswan-swanctl = {
          path = [pkgs.coreutils pkgs.gnused];
          preStart = lib.mkBefore ''
            ${render_swanctl}
          '';
        };

        networking.firewall = {
          checkReversePath = lib.mkDefault false;
          extraCommands = ''
            iptables --insert INPUT --protocol esp --jump ACCEPT
          '';
          extraStopCommands = ''
            iptables --delete INPUT --protocol esp --jump ACCEPT || true
          '';
        };

        environment.systemPackages = [opts.package];
      });
}
