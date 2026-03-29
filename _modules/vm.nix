{lib, ...}: {
  virtualisation.vmVariant = {
    my = {
      nix.monitor_layout = lib.mkForce null;
      nvidia.enable = lib.mkForce false;
      azure-vpn.enable = lib.mkForce false;
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
          target = "/mnt/vm-bundle";
        };
      };
    };

    hardware = {
      # disable container toolkit error
      nvidia-container-toolkit.enable = lib.mkForce false;
    };

    system.activationScripts = {
      vm-bundle = lib.stringAfter ["specialfs"] ''
        ln -sfnT /mnt/vm-bundle /run/vm-bundle

        if [ ! -d /run/vm-bundle ]; then
          echo "error: VM bundle mount not ready: /run/vm-bundle" >&2
          exit 1
        fi

        if [ ! -f /run/vm-bundle/age/key.txt ]; then
          echo "error: required VM bundle file missing: /run/vm-bundle/age/key.txt" >&2
          exit 1
        fi

        install -d -m 700 /root/.age
        install -m 600 /run/vm-bundle/age/key.txt /root/.age/key.txt

        if [ -f /run/vm-bundle/ssh/id_ed25519 ]; then
          install -d -m 700 /root/.ssh
          install -m 600 /run/vm-bundle/ssh/id_ed25519 /root/.ssh/id_ed25519
        fi
      '';

      setupSecretsForUsers.deps = ["vm-bundle"];
      setupSecrets.deps = ["vm-bundle"];
    };
  };
}
