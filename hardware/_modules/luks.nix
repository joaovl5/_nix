{
  config,
  lib,
  pkgs,
  ...
} @ args: let
  inherit (lib) mkOption mkEnableOption types;

  public_data = import ../../_modules/public.nix args;
  default_ssh_authorized_keys = [
    # all host keys should go here
    # - git_ro_key
    # - servers/etc
    public_data.ssh_key
  ];

  luks_cfg = config.my_luks;
in {
  options.my_luks = {
    ssh = {
      enable =
        mkEnableOption "Enable SSH unlocking for LUKS"
        // {
          default = false;
        };

      port = mkOption {
        description = "Port initrd sshd service";
        type = types.int;
        default = 2223;
      };

      authorized_keys = mkOption {
        description = "Authorized keys to connect through SSH";
        type = types.listOf types.str;
        default = default_ssh_authorized_keys;
      };

      use_dhcp = mkEnableOption "Setup DHCP in boot.kernelParams for assigning a dynamic IP for the host." // {default = true;};
    };
  };

  config = let
    ssh_initrd_key_path = "/etc/secrets/initrd/ssh_luks_key";
  in {
    # Generate initrd SSH host key on first boot (ends up in unencrypted /boot anyway)
    system.activationScripts.generateInitrdHostKey = ''
      if [[ ! -f ${ssh_initrd_key_path} ]]; then
        mkdir -p /etc/secrets/initrd
        ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${ssh_initrd_key_path} -q
      fi
    '';

    boot.kernelParams = ["ip=dhcp"];
    # boot.kernelParams = [
    #   "ip=::::${config.networking.hostName}::dhcp"
    # ];
    boot.initrd = {
      unl0kr = {
        enable = true;
        settings = {
          general.animations = true;
          general.backend = "drm";
          theme = {
            default = "pmos-dark";
            alternate = "pmos-light";
          };
        };
      };

      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];
      systemd = {
        enable = true;
        network = {
          enable = true;
        };
        users.root.shell = "/bin/systemd-tty-ask-password-agent";
        storePaths = with pkgs; [
          curl
          gawk
          iproute2
          coreutils
        ];
      };
      # [!] assumes facter will already define kernel modules for networking
      network = {
        enable = true;
        # udhcpc.enable = true;
        # flushBeforeStage2 = true;
        ssh = {
          enable = true;
          inherit (luks_cfg.ssh) port;
          authorizedKeys = luks_cfg.ssh.authorized_keys;
          # Generated on first boot via system.activationScripts.generateInitrdHostKey
          hostKeys = [ssh_initrd_key_path];
        };
        # postCommands = ''
        #   # Automatically ask for password upon SSH login
        #   echo 'cryptsetup-askpass || echo "Unlock was successful, exiting SSH session" && exit 1' >> /root/.profile
        # '';
      };
    };
  };
  # config = mkMerge [
  #   (mkIf (luks_cfg.ssh.enable && luks_cfg.ssh.use_dhcp) {
  #     boot.kernelParams = [
  #       "ip=::::${config.networking.hostName}::dhcp"
  #     ];
  #   })
  #   (mkIf luks_cfg.ssh.enable {
  #     boot.initrd = {
  #       # [!] assumes facter will already define kernel modules for networking
  #       network = {
  #         enable = true;
  #         udhcpc.enable = true;
  #         flushBeforeStage2 = true;
  #         ssh = {
  #           enable = true;
  #           port = luks_cfg.ssh.port;
  #           authorizedKeys = luks_cfg.ssh.authorized_keys;
  #           hostKeys = luks_cfg.ssh.host_key_files;
  #         };
  #         postCommands = ''
  #           # Automatically ask for password upon SSH login
  #           echo 'cryptsetup-askpass || echo "Unlock was successful, exiting SSH session" && exit 1' >> /root/.profile
  #         '';
  #       };
  #     };
  #   })
  # ];
}
