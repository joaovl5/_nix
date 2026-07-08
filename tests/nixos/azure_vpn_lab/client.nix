_: {
  lib,
  pkgs,
  azure_vpn_lab,
  test_azure_vpn_material,
  ...
}: let
  cfg = azure_vpn_lab;
in {
  imports = [
    ../../common/base_node.nix
    (import ../../../modules/aspects/base/options.nix {}).den.aspects.base-options.nixos
    ../../common/_sops_stub.nix
    (import ../../../modules/aspects/desktop/network/azure-vpn/default.nix {}).den.aspects.desktop.nixos
  ];

  system = {
    stateVersion = "25.11";
    activationScripts."azure-vpn-test-secrets" = lib.stringAfter ["specialfs"] ''
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/gateway_fqdn /run/secrets/azure_vpn_gateway_fqdn
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/remote_id /run/secrets/azure_vpn_remote_id
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/client_id /run/secrets/azure_vpn_client_id
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/remote_ts /run/secrets/azure_vpn_remote_ts
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/ca.pem /run/secrets/azure_vpn_ca_cert
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/client.pem /run/secrets/azure_vpn_client_cert
      ${pkgs.coreutils}/bin/install -Dm400 ${test_azure_vpn_material}/client-key.pem /run/secrets/azure_vpn_client_key
    '';
  };

  my = {
    nix = {
      hostname = "azure-vpn-client";
      username = "tester";
    };

    "azure-vpn" = {
      enable = true;
      secrets.sops_file = "/dev/null";
      connection = {
        inherit (cfg) ike_proposals;
        inherit (cfg) esp_proposals;
      };
    };
  };

  virtualisation.vlans = [1];

  networking.interfaces.eth1 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = cfg.public.client_ipv4;
        prefixLength = cfg.public.prefix_length;
      }
    ];
  };

  networking.hosts = {
    ${cfg.public.gateway_ipv4} = [cfg.gateway_fqdn];
    ${cfg.private.resource_ipv4} = [cfg.private.resource_name];
  };

  environment.systemPackages = with pkgs; [
    curl
    getent
    iproute2
    strongswan
  ];
}
