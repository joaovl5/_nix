{
  mylib,
  config,
  pkgs,
  ...
}: let
  inherit (pkgs) lib;
  inherit (lib) mkOption;

  my = mylib.use config;
  o = my.options;
  inherit (o) t;
  s = my.secrets;

  Database = t.submodule (_: {
    options = {
      name = mkOption {
        description = "Database and matching role name";
        type = t.str;
      };
      password = mkOption {
        description = "Path to a secret file containing the role password";
        type = t.str;
      };
    };
  });

  Admin = t.submodule (_: {
    options = {
      password = mkOption {
        description = "Path to a secret file containing the admin password";
        type = t.str;
      };
    };
  });

  authentication = databases:
    lib.concatStringsSep "\n" (
      [
        "local all postgres peer"
        "local all all reject"
        "host all admin 127.0.0.1/32 scram-sha-256"
        "host all admin ::1/128 scram-sha-256"
      ]
      ++ lib.concatMap (db: [
        "host ${db.name} ${db.name} 127.0.0.1/32 scram-sha-256"
        "host ${db.name} ${db.name} ::1/128 scram-sha-256"
      ])
      databases
    );
in
  o.module "unit.postgres" (with o; {
    enable = toggle "Enable Postgres" false;
    data_dir = optional "Directory for postgres state data" t.str {};
    admin = mkOption {
      description = "Admin user credentials";
      type = Admin;
    };
    databases = opt "Database/user declarations" (t.listOf Database) [];
  }) {} (
    opts:
      o.when opts.enable (
        let
          computed_data_dir =
            if opts.data_dir != null
            then opts.data_dir
            else "/var/lib/postgresql/${pkgs.postgresql.psqlSchema}";

          database_names = builtins.map (db: db.name) opts.databases;
          database_names_checked =
            if builtins.elem "admin" database_names
            then builtins.throw "unit.postgres.databases must not contain a database named \"admin\""
            else database_names;

          require_path = label: value:
            if value != null
            then value
            else builtins.throw "unit.postgres.${label} is required";

          normalized_databases = builtins.map (db: db // {password = require_path "databases.${db.name}.password" db.password;}) opts.databases;
          admin_password_path = require_path "admin.password" opts.admin.password;

          db_user_entries =
            builtins.map (db: {
              inherit (db) name;
              ensureDBOwnership = true;
              ensureClauses = {
                login = true;
              };
            })
            normalized_databases;

          database_password_sync =
            lib.concatMapStringsSep "\n" (db: ''
              sync_password ${lib.escapeShellArg db.name} ${lib.escapeShellArg db.password}
            '')
            normalized_databases;
        in {
          my."unit.postgres".admin.password = lib.mkDefault (s.secret_path "postgres_admin_password");
          sops.secrets."postgres_admin_password" = s.mk_secret "${s.dir}/postgres.yaml" "admin_password" {};

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
            enableTCPIP = true;
            dataDir = computed_data_dir;
            authentication = lib.mkForce (authentication normalized_databases);
            settings.listen_addresses = lib.mkForce "127.0.0.1,::1";
            ensureDatabases = ["admin"] ++ database_names_checked;
            ensureUsers =
              [
                {
                  name = "admin";
                  ensureDBOwnership = true;
                  ensureClauses = {
                    login = true;
                    superuser = true;
                  };
                }
              ]
              ++ db_user_entries;
          };

          systemd.services.postgresql-password-sync = {
            description = "Synchronize PostgreSQL role passwords";
            wantedBy = ["multi-user.target"];
            requires = ["postgresql.service" "postgresql-setup.service"];
            after = ["postgresql.service" "postgresql-setup.service"];
            path = with pkgs; [util-linux];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              set -euo pipefail

              psql_cmd() {
                runuser -u postgres -- ${pkgs.postgresql}/bin/psql -d postgres -v ON_ERROR_STOP=1 "$@"
              }

              sync_password() {
                local name="$1"
                local password_path="$2"
                local password
                password="$(cat "$password_path")"

                psql_cmd -v name="$name" -v password="$password" <<'SQL'
              ALTER ROLE :"name" WITH PASSWORD :'password';
              SQL
              }

              sync_password admin ${lib.escapeShellArg admin_password_path}
              ${database_password_sync}
            '';
          };
        }
      )
  )
