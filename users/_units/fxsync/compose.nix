{
  port,
  data_dir,
}: {
  name = "fxsync";
  services = {
    syncstorage = {
      image = "mozilla/syncstorage-rs:0.13.6";
      container_name = "firefox_syncstorage";
      environment = {
        SYNC_HOST = "0.0.0.0";
        SYNC_HUMAN_LOGS = "true";
        SYNC_MASTER_SECRET = "$SYNC_MASTER_SECRET";
        SYNC_SYNCSTORAGE__DATABASE_URL = "mysql://$MARIADB_USER:$MARIADB_PASSWORD@syncstorage_db:3306/syncstorage";
        SYNC_SYNCSTORAGE__ENABLED = "true";
        # SYNC_SYNCSTORAGE__ENABLE_QUOTA = "true";
        # SYNC_SYNCSTORAGE__ENFORCE_QUOTA = "true";
        SYNC_TOKENSERVER__ENABLED = "true";
        SYNC_TOKENSERVER__RUN_MIGRATIONS = "true";
        SYNC_TOKENSERVER__NODE_TYPE = "mysql";
        SYNC_TOKENSERVER__DATABASE_URL = "mysql://$MARIADB_USER:$MARIADB_PASSWORD@tokenserver_db:3306/tokenserver";
        SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN = "api.accounts.firefox.com";
        SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL = "https://oauth.accounts.firefox.com/v1";
        SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET = "$METRICS_HASH_SECRET";
        SYNC_TOKENSERVER__ADDITIONAL_BLOCKING_THREADS_FOR_FXA_REQUESTS = "2";
        RUST_LOG = "info";
      };
      healthcheck = {
        test = ["CMD" "curl" "-f" "http://localhost:8000/__heartbeat__"];
        interval = "30s";
        timeout = "10s";
        retries = 5;
      };
      restart = "unless-stopped";
      depends_on = ["syncstorage_db" "tokenserver_db"];
      ports = ["${toString port}:8000"];
    };

    syncstorage_db = {
      image = "mariadb:10.11";
      container_name = "firefox_syncstorage_db";
      environment = {
        MARIADB_RANDOM_ROOT_PASSWORD = "true";
        MARIADB_DATABASE = "syncstorage";
        MARIADB_USER = "$MARIADB_USER";
        MARIADB_PASSWORD = "$MARIADB_PASSWORD";
        MARIADB_AUTO_UPGRADE = "true";
      };
      volumes = ["${data_dir}/sync:/var/lib/mysql"];
      restart = "unless-stopped";
    };

    tokenserver_db = {
      image = "mariadb:10.11";
      container_name = "firefox_tokenserver_db";
      environment = {
        MARIADB_RANDOM_ROOT_PASSWORD = "true";
        MARIADB_DATABASE = "tokenserver";
        MARIADB_USER = "$MARIADB_USER";
        MARIADB_PASSWORD = "$MARIADB_PASSWORD";
        MARIADB_AUTO_UPGRADE = "true";
      };
      volumes = ["${data_dir}/token:/var/lib/mysql"];
      restart = "unless-stopped";
    };

    tokenserver_db_init = {
      image = "mariadb:10.11";
      container_name = "firefox_tokenserver_db_init";
      depends_on = ["tokenserver_db" "syncstorage"];
      restart = "no";
      environment = {
        MARIADB_USER = "$MARIADB_USER";
        MARIADB_PASSWORD = "$MARIADB_PASSWORD";
        DOMAIN = "$DOMAIN";
      };
      entrypoint = [
        "bash"
        "-c"
        ''
          IS_DONE=10
          while [ $$IS_DONE -gt 0 ]; do
              echo "INSERT IGNORE INTO services (id, service, pattern) VALUES ('1', 'sync-1.5', '{node}/1.5/{uid}');
              INSERT INTO nodes (id, service, node, available, current_load, capacity, downed, backoff)
              VALUES ('1', '1', '$$DOMAIN', '1', '0', '5', '0', '0') ON DUPLICATE KEY UPDATE node='$$DOMAIN';"|mysql --host=tokenserver_db --user=$$MARIADB_USER --password=$$MARIADB_PASSWORD tokenserver
              RC=$$?
              echo "mysql return code was $$RC"
              if [ $$RC == 0 ] ; then
              IS_DONE=0
              echo 'Done!'
              exit 0
              else
              echo 'Waiting for tables...'
              sleep 5
              ((IS_DONE--))
              fi
          done
          echo 'Giving up, sorry'
          exit 42
        ''
      ];
    };
  };
}
