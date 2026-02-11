{
  config,
  lib,
  ...
} @ args: let
  inherit (lib) mkOption mkIf mkMerge mkEnableOption types;

  public_data = import ../../_modules/public.nix args;
  default_ssh_authorized_keys = [
    # TODO all host keys should go here
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
        type = with types; listOf str;
        default = default_ssh_authorized_keys;
      };

      host_key_files = mkOption {
        description = "File paths to use as ssh host keys";
        type = with types; listOf str;
        default = [
          "/etc/secrets/initrd/ssh_host_ed25519_key"
        ];
      };
    };
  };

  config = mkMerge [
    (mkIf luks_cfg.ssh.enable {
      boot.initrd = {
        # [!] assumes facter will already define kernel modules for networking
        network = {
          enable = true;
          udhcpc.enable = true;
          flushBeforeStage2 = true;
          ssh = {
            enable = true;
            port = luks_cfg.ssh.port;
            authorizedKeys = luks_cfg.ssh.authorized_keys;
            hostKeys = luks_cfg.ssh.host_key_files;
          };
          postCommands = ''
            # Automatically ask for password upon SSH login
            echo 'cryptsetup-askpass || echo "Unlock was successful, exiting SSH session" && exit 1' >> /root/.profile
          '';
        };
      };
    })
  ];
}
