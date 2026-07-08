{
  self,
  inputs,
  mylib,
  pkgs,
  system,
  ...
} @ args: let
  azure_vpn_lab = {
    gateway_fqdn = "azure-vpn-gateway.test";
    client_id = "azure-vpn-client.test";

    public = {
      gateway_ipv4 = "192.0.2.1";
      client_ipv4 = "192.0.2.2";
      prefix_length = 24;
    };

    private = {
      gateway_ipv4 = "198.51.100.1";
      resource_ipv4 = "198.51.100.5";
      subnet_cidr = "198.51.100.0/24";
      prefix_length = 24;
      resource_name = "private-resource.azure-vpn.test";
      service_port = 18080;
    };

    p2s_pool_cidr = "172.31.200.0/24";
    p2s_pool_source_prefix = "172.31.200.";

    ike_proposals = [
      "aes256gcm16-prfsha384-ecp384"
      "aes256gcm16-prfsha384-modp2048"
    ];
    esp_proposals = ["aes256gcm16"];
  };

  test_azure_vpn_material = pkgs.runCommand "azure-vpn-test-material" {nativeBuildInputs = [pkgs.openssl];} ''
    set -euo pipefail
    umask 077

    work="$TMPDIR/azure-vpn-test-material"
    mkdir -p "$work" "$out"

    not_before=20200101000000Z
    not_after=21200101000000Z

    openssl genrsa -out "$work/ca-key.pem" 2048
    openssl req -new \
      -key "$work/ca-key.pem" \
      -subj "/CN=Azure VPN Lab Test Root" \
      -out "$work/ca.csr"
    cat > "$work/ca.ext" <<EOF
    basicConstraints = critical,CA:true
    keyUsage = critical,keyCertSign,cRLSign
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    EOF
    openssl x509 -req \
      -in "$work/ca.csr" \
      -signkey "$work/ca-key.pem" \
      -sha256 \
      -not_before "$not_before" \
      -not_after "$not_after" \
      -set_serial 0x1001 \
      -extfile "$work/ca.ext" \
      -out "$out/ca.pem"

    openssl genrsa -out "$out/gateway-key.pem" 2048
    openssl req -new \
      -key "$out/gateway-key.pem" \
      -subj "/CN=${azure_vpn_lab.gateway_fqdn}" \
      -out "$work/gateway.csr"
    cat > "$work/gateway.ext" <<EOF
    subjectAltName = DNS:${azure_vpn_lab.gateway_fqdn}
    extendedKeyUsage = serverAuth
    keyUsage = digitalSignature, keyEncipherment
    EOF
    openssl x509 -req \
      -in "$work/gateway.csr" \
      -CA "$out/ca.pem" \
      -CAkey "$work/ca-key.pem" \
      -sha256 \
      -not_before "$not_before" \
      -not_after "$not_after" \
      -set_serial 0x1002 \
      -extfile "$work/gateway.ext" \
      -out "$out/gateway.pem"

    openssl genrsa -out "$out/client-key.pem" 2048
    openssl req -new \
      -key "$out/client-key.pem" \
      -subj "/CN=${azure_vpn_lab.client_id}" \
      -out "$work/client.csr"
    cat > "$work/client.ext" <<EOF
    subjectAltName = DNS:${azure_vpn_lab.client_id}
    extendedKeyUsage = clientAuth
    keyUsage = digitalSignature, keyEncipherment
    EOF
    openssl x509 -req \
      -in "$work/client.csr" \
      -CA "$out/ca.pem" \
      -CAkey "$work/ca-key.pem" \
      -sha256 \
      -not_before "$not_before" \
      -not_after "$not_after" \
      -set_serial 0x1003 \
      -extfile "$work/client.ext" \
      -out "$out/client.pem"

    printf '%s\n' '${azure_vpn_lab.gateway_fqdn}' > "$out/gateway_fqdn"
    printf '%s\n' '${azure_vpn_lab.gateway_fqdn}' > "$out/remote_id"
    printf '%s\n' '${azure_vpn_lab.client_id}' > "$out/client_id"
    printf '%s\n' '${azure_vpn_lab.private.subnet_cidr}' > "$out/remote_ts"
    chmod 0400 "$out"/*
  '';
in
  # Three-node offline Azure P2S shape: client initiates IKEv2 certificate auth to an
  # Azure-like gateway FQDN on the public VLAN, then reaches a private resource on a
  # protected VNet VLAN through the negotiated IPsec tunnel and virtual IP pool.
  mylib.tests.mk_test {
    name = "azure_vpn_lab";
    python_module_name = "azure_vpn_lab";

    node.pkgsReadOnly = false;
    node.specialArgs = {
      inherit self inputs mylib system azure_vpn_lab test_azure_vpn_material;
      inherit (args) globals;
    };

    nodes = {
      gateway = import ./gateway.nix args;
      client = import ./client.nix args;
      resource = import ./resource.nix args;
    };
  }
