{
  self,
  inputs,
  mylib,
  system,
  pkgs,
  ...
} @ args: let
  test_wireguard_keys = pkgs.runCommand "wireguard-test-keys" {} ''
    set -euo pipefail
    umask 077
    mkdir -p "$out"

    printf '%s\n' 'mFksuxtM3IxE3rNDmQ5sJ+PrYuFwe4PVIEzOP7ygL0k=' > "$out/relay.private"
    printf '%s\n' '0nFEgTPX3ixlV3FeF2R2NTvONDaJW2svQXhSRJEnJ24=' > "$out/relay.public"
    printf '%s\n' 'QIXJYXt24Ubo3cjPaZefxzMhMwXFIFmAYESXSEUoLm4=' > "$out/isolated-host.private"
    printf '%s\n' 'mxbyLpSo47s6dAQLKaNj38mLmurAC6YIOOZJTSRO6kA=' > "$out/isolated-host.public"
    printf '%s\n' 'APDovwpdFffE40Ksm3EZgWB6gChjKb4CZp1wWTfZcXU=' > "$out/isolated-namespace.private"
    printf '%s\n' 'wTm9X3XLcFk3KCijDsUdqpjYoN7FF7OOElCnrm10Fmc=' > "$out/isolated-namespace.public"

    chmod 0400 "$out"/*.private
    chmod 0444 "$out"/*.public
  '';
in
  # Three-node topology: relay publishes the host-side WireGuard endpoint, isolated runs both
  # host and namespace peers under test, and probe provides observer/dns/leak fixtures on the
  # shared VLAN. Keep node roles obvious here because the Python driver reasons about them by name.
  mylib.tests.mk_test {
    name = "wireguard_tunnels";
    python_module_name = "wireguard_tunnels";

    node.pkgsReadOnly = false;
    node.specialArgs = {
      inherit self inputs mylib system test_wireguard_keys;
    };

    nodes = {
      relay = import ./relay.nix args;
      isolated = import ./isolated.nix args;
      probe = import ./probe.nix args;
    };
  }
