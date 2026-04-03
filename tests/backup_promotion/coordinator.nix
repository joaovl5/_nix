_: {
  lib,
  config,
  self,
  mylib,
  test_ssh_key,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  sops_stub = import ../_sops_stub.nix;
in {
  imports = [
    sops_stub
    ../../_modules/options.nix
    ../../users/_units/backup
  ];

  nixpkgs.overlays = self._channels.overlays;

  my.nix = o.def {
    hostname = "coordinator";
    username = "tester";
    name = "tester";
    email = "testbox@trll.ing";
  };

  system = {
    stateVersion = "25.11";
    activationScripts = {
      "backup-test-secrets" = lib.stringAfter ["specialfs"] ''
        mkdir -p /run/secrets
        printf '%s' 'test-password-a' > /run/secrets/backup_restic_password_A
        printf '%s' 'test-password-b' > /run/secrets/backup_restic_password_B
        chmod 444 /run/secrets/backup_restic_password_A
        chmod 444 /run/secrets/backup_restic_password_B

        mkdir -p /root/.ssh
        cp ${test_ssh_key}/id_ed25519 /root/.ssh/id_ed25519_backup
        chmod 600 /root/.ssh/id_ed25519_backup
        cat > /root/.ssh/config <<'EOF'
        Host storage
          User backup-user
          IdentityFile /root/.ssh/id_ed25519_backup
          StrictHostKeyChecking no
          UserKnownHostsFile /dev/null
        EOF
        chmod 600 /root/.ssh/config
      '';

      "backup-repos-dir" = lib.stringAfter ["users"] ''
        mkdir -p /var/lib/backups/repos
        chmod 777 /var/lib/backups/repos
      '';
    };
  };

  environment.systemPackages = [pkgs.restic];

  my."unit.backup" = {
    enable = true;
    destinations.A = {
      enable = true;
      backend = "filesystem";
      repository_template = "/var/lib/backups/repos/{host}";
      password_secret = {
        name = "backup_restic_password_A";
        file = "backups.yaml";
        key = "restic_a_password";
      };
    };
    destinations.B = {
      enable = true;
      backend = "sftp";
      repository_template = "sftp:backup-user@storage:/var/lib/backups/repos/{host}";
      password_secret = {
        name = "backup_restic_password_B";
        file = "backups.yaml";
        key = "restic_b_password";
      };
    };
    policies.test = {
      timerConfig = {
        OnCalendar = "yearly";
        Persistent = "false";
      };
      promotion_timerConfig = {
        OnCalendar = "yearly";
        Persistent = "false";
      };
      forget_timerConfig = {
        OnCalendar = "yearly";
        Persistent = "false";
      };
      prune_timerConfig = {
        OnCalendar = "yearly";
        Persistent = "false";
      };
      check_timerConfig = {
        OnCalendar = "yearly";
        Persistent = "false";
      };
      promote_to = ["B"];
      forget = ["--keep-last 2" "--group-by host"];
    };
    host_items."my-path" = {
      kind = "path";
      policy = "test";
      path.paths = ["/test-data"];
    };
  };
}
