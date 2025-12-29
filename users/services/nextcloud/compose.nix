{
  nextcloud_http_port ? 1009,
  nextcloud_admin_user ? "admin",
  nextcloud_admin_password ? "adminchangeme",
  nextcloud_trusted_domain ? "",
  nextcloud_mount_path,
  mariadb_database ? "nextcloud_db",
  mariadb_user ? "nextcloud_user",
  mariadb_password ? "nextcloud_pw",
  mariadb_root_password ? "nextcloud_root_pw",
  mariadb_timezone ? "America/Sao_Paulo",
  redis_password ? "nextcloud_pw",
}: {
  services = {
    nextcloud_db = {
      image = "mariadb:11.4";
      container_name = "nextcloud_db";
      hostname = "nextcloud_db";
      command = "--transaction-isolation=READ-COMMITTED --innodb_read_only_compressed=OFF";
      expose = [3306];
      environment = {
        "MYSQL_DATABASE" = mariadb_database;
        "MYSQL_USER" = mariadb_user;
        "MYSQL_PASSWORD" = mariadb_password;
        "MYSQL_ROOT_PASSWORD" = mariadb_root_password;
        "MYSQL_INITDB_SKIP_TZINFO" = 1;
        "MARIADB_AUTO_UPGRADE" = 1;
        "PUID" = 1000;
        "PGID" = 1000;
        "TZ" = mariadb_timezone;
      };
      volumes = [
        "${nextcloud_mount_path}/mariadb:/var/lib/mysql"
      ];
    };
    nextcloud_redis = {
      image = "redis:alpine";
      container_name = "nextcloud_redis";
      hostname = "nextcloud_redis";
      command = [
        "/bin/sh"
        "-c"
        "redis-server --requirepass \"${redis_password}\""
      ];
    };
    nextcloud_app = {
      image = "nextcloud:31-apache";
      container_name = "nextcloud_app";
      hostname = "nextcloud_app";
      ports = [
        "${builtins.toString nextcloud_http_port}:80"
      ];
      depends_on = ["nextcloud_db" "nextcloud_redis"];
      environment = {
        "NEXTCLOUD_ADMIN_USER" = nextcloud_admin_user;
        "NEXTCLOUD_ADMIN_PASSWORD" = nextcloud_admin_password;
        "NEXTCLOUD_TRUSTED_DOMAINS" = nextcloud_trusted_domain;
        "OVERWRITEHOST" = nextcloud_trusted_domain;
        "OVERWRITECLIURL" = nextcloud_trusted_domain;
        # "TRUSTED_PROXIES" = "127.0.0.1";
        # mysql
        "MYSQL_HOST" = "nextcloud_db";
        "MYSQL_DATABASE" = mariadb_database;
        "MYSQL_USER" = mariadb_user;
        "MYSQL_PASSWORD" = mariadb_password;
        # redis
        "REDIS_HOST" = "nextcloud_redis";
        "REDIS_HOST_PASSWORD" = redis_password;
      };
      volumes = [
        "${nextcloud_mount_path}/app:/var/www/html"
      ];
    };
  };
}
