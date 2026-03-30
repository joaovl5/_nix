{lib, options, ...}: let
  vm_bundle_contract = import ./_vm_bundle_contract.nix;
  has_nvidia_option = lib.hasAttrByPath ["my" "nvidia" "enable"] options;
in {
  virtualisation.vmVariant = {
    my = {
      nix.monitor_layout = lib.mkForce null;
      azure-vpn.enable = lib.mkForce false;
    }
    // lib.optionalAttrs has_nvidia_option {
      nvidia.enable = lib.mkForce false;
    };

    services.flatpak.enable = lib.mkForce false;
    virtualisation = {
      cores = lib.mkDefault 4;
      memorySize = lib.mkDefault 6192;
      docker.enable = lib.mkForce false;
      libvirtd.enable = lib.mkForce false;
      qemu.options = [
        "-display sdl,gl=on"
        "-vga none"
        "-device virtio-vga-gl"
      ];
      sharedDirectories = {
        vmBundle = {
          source = "$VM_BUNDLE_DIR";
          target = vm_bundle_contract.shared_directory_target;
        };
      };
    };

    hardware = {
      # disable container toolkit error
      nvidia-container-toolkit.enable = lib.mkForce false;
    };

    system.activationScripts = {
      vm-bundle = lib.stringAfter ["specialfs"] vm_bundle_contract.activation_script;

      setupSecretsForUsers.deps = ["vm-bundle"];
      setupSecrets.deps = ["vm-bundle"];
    };
  };
}
