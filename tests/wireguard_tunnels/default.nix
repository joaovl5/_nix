{
  self,
  inputs,
  mylib,
  system,
  pkgs,
  ...
} @ args: let
  test_wireguard_keys =
    pkgs.runCommand "wireguard-test-keys" {
      nativeBuildInputs = [pkgs.wireguard-tools];
    } ''
      set -euo pipefail
      umask 077
      mkdir -p "$out"

      generate_pair() {
        local name="$1"
        wg genkey | tee "$out/$name.private" | wg pubkey > "$out/$name.public"
        chmod 0400 "$out/$name.private"
        chmod 0444 "$out/$name.public"
      }

      generate_pair relay
      generate_pair isolated-host
      generate_pair isolated-namespace
    '';
in
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
