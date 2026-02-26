{
  data_dir,
  db_port_syncstorage,
  db_port_tokenserver,
}: {
  name = "fxsync";
  services = {
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
      ports = ["127.0.0.1:${toString db_port_syncstorage}:3306"];
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
      ports = ["127.0.0.1:${toString db_port_tokenserver}:3306"];
      volumes = ["${data_dir}/token:/var/lib/mysql"];
      restart = "unless-stopped";
    };
  };
}
