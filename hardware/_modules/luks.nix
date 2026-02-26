{pkgs, ...} @ args: let
  o = import ../../_lib/options args;

  public_data = import ../../_modules/public.nix args;
  default_ssh_authorized_keys = [
    public_data.ssh_key
  ];
in
  o.module "luks" (with o; {
    ssh = {
      enable = toggle "Enable SSH unlocking for LUKS" false;
      port = opt "Port initrd sshd service" t.int 2223;
      authorized_keys = opt "Authorized keys to connect through SSH" (t.listOf t.str) default_ssh_authorized_keys;
    };
  }) {} (
    opts: let
      ssh_initrd_key_path = "/etc/secrets/initrd/ssh_luks_key";
    in
      o.when opts.ssh.enable {
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
            ssh = {
              enable = true;
              inherit (opts.ssh) port;
              authorizedKeys = opts.ssh.authorized_keys;
              hostKeys = [ssh_initrd_key_path];
            };
          };
        };
      }
  )
