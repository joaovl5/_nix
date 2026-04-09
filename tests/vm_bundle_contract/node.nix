_: {
  lib,
  pkgs,
  ...
}: let
  sops_stub = {lib, ...}: {
    options.sops.secrets = lib.mkOption {
      default = {};
      type = lib.types.lazyAttrsOf lib.types.anything;
    };
  };

  vm_bundle_contract = import ../../_modules/_vm_bundle_contract.nix;

  vm_bundle_fixture = pkgs.runCommand "vm-bundle-fixture" {} ''
    mkdir -p "$out/age" "$out/ssh"
    printf '%s' 'synthetic-age-key' > "$out/age/key.txt"
    printf '%s' 'synthetic-ssh-key' > "$out/ssh/id_ed25519"
  '';
in {
  imports = [
    sops_stub
    ../base_node.nix
    ../../_modules/options.nix
    ../../hardware/_modules/nvidia.nix
    ../../_modules/vm.nix
  ];

  my.nvidia.enable = false;
  system.stateVersion = "25.11";

  system.activationScripts."vm-bundle" =
    lib.stringAfter ["specialfs"] vm_bundle_contract.activation_script;

  virtualisation.sharedDirectories.vmBundle = {
    source = toString vm_bundle_fixture;
    target = vm_bundle_contract.shared_directory_target;
    securityModel = "mapped-xattr";
  };
}
