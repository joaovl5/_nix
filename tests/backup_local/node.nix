_: {
  lib,
  config,
  self,
  mylib,
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
    hostname = "machine";
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
        chmod 444 /run/secrets/backup_restic_password_A
      '';

      "backup-repos-init" = lib.stringAfter ["users" "backup-test-secrets"] ''
        mkdir -p /var/lib/backups/repos
      '';
    };
  };

  environment.systemPackages = [pkgs.postgresql pkgs.restic];

  services.postgresql = {
    enable = true;
    ensureDatabases = ["testdb"];
  };

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
      promote_to = [];
      forget = ["--keep-last 2" "--group-by host"];
    };
    host_items = {
      "my-path" = {
        kind = "path";
        policy = "test";
        path.paths = ["/test-data"];
      };
      "my-custom" = {
        kind = "custom";
        policy = "test";
        custom = {
          command = "printf 'backup-custom-data'";
          stdin_filename = "custom.dat";
        };
      };
      "my-postgres" = {
        kind = "postgres_dump";
        policy = "test";
        run_as_user = "postgres";
        postgres_dump.database = "testdb";
      };
    };
  };
}
