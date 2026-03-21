{
  config,
  mylib,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
in
  o.module "azure-vpn" (with o; {
    enable = toggle "Enable Azure P2S VPN via IKEv2/EAP-TLS" false;

    gateway = opt "Azure VPN gateway FQDN" t.str null;
    gateway_id = opt "Azure VPN gateway ID (without azuregateway prefix)" t.str null;
    identity = opt "Client identity (certificate CN)" t.str null;
    routes = opt "Routes to push through VPN" (t.listOf t.str) [];
  }) {} (
    opts: let
      inherit (opts) enable gateway gateway_id identity routes;

      swanctl_dir = "/etc/swanctl";

      deploy_certs_script = pkgs.writeShellScript "azure-vpn-deploy-certs" ''
        set -euo pipefail

        mkdir -p "${swanctl_dir}/x509"
        mkdir -p "${swanctl_dir}/x509ca"
        mkdir -p "${swanctl_dir}/private"

        cat "${s.secret_path "azure_vpn_client_cert"}" > "${swanctl_dir}/x509/client.crt"
        cat "${s.secret_path "azure_vpn_client_key"}" > "${swanctl_dir}/private/client.key"
        cat "${s.secret_path "azure_vpn_ca_cert"}" > "${swanctl_dir}/x509ca/ca.pem"

        chmod 644 "${swanctl_dir}/x509/client.crt"
        chmod 600 "${swanctl_dir}/private/client.key"
        chmod 644 "${swanctl_dir}/x509ca/ca.pem"
      '';
    in
      o.when enable {
        assertions = [
          {
            assertion = gateway != null && gateway_id != null && identity != null;
            message = "azure-vpn: gateway, gateway_id, and identity must be set";
          }
        ];

        sops.secrets = {
          "azure_vpn_client_cert" = s.mk_secret "${s.dir}/work/azure-vpn.yaml" "client_cert" {};
          "azure_vpn_client_key" = s.mk_secret "${s.dir}/work/azure-vpn.yaml" "client_key" {};
          "azure_vpn_ca_cert" = s.mk_secret "${s.dir}/work/azure-vpn.yaml" "ca_cert" {};
        };

        services.strongswan-swanctl = {
          enable = true;

          strongswan.extraConfig = ''
            charon {
              filelog {
                charon-debug {
                  path = /var/log/charon-debug.log
                  tls = 4
                  cfg = 2
                  lib = 2
                }
              }
            }
          '';

          swanctl = {
            connections.azure = {
              version = 2;
              mobike = true;
              rekey_time = "0";
              proposals = ["aes256gcm16-prfsha384-modp2048"];

              local_addrs = ["%any"];
              remote_addrs = [gateway];

              local.main = {
                auth = "eap-tls";
                certs = ["client.crt"];
                eap_id = identity;
              };

              remote.main = {
                auth = "pubkey";
                id = "%any";
              };

              children.azure = {
                remote_ts =
                  if builtins.length routes > 0
                  then routes
                  else ["0.0.0.0/0"];
                esp_proposals = ["aes256gcm16"];
                dpd_action = "restart";
                mode = "tunnel";
                policies = true;
              };
            };
          };
        };

        systemd.services.strongswan-swanctl = {
          serviceConfig.ExecStartPre = [deploy_certs_script];
        };
      }
  )
