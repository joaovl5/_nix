{
  self,
  inputs,
  mylib,
  system,
  pkgs,
  ...
} @ args: let
  test_ssh_key =
    pkgs.runCommand "backup-test-ssh-key" {
      buildInputs = [pkgs.openssh];
    } ''
      mkdir -p "$out"
      ssh-keygen -t ed25519 -N "" -C "backup-test-key" -f "$out/id_ed25519"
    '';
in
  mylib.tests.mk_test {
    name = "backup_promotion";
    python_module_name = "backup_promotion";

    node.pkgsReadOnly = false;
    node.specialArgs = {
      inherit self inputs mylib system test_ssh_key;
    };

    nodes.coordinator = import ./coordinator.nix args;
    nodes.storage = import ./storage.nix args;
  }
