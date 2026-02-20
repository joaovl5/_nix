{
  lobe_db_name,
  lobe_db_password,
  pg_data_dir,
  redis_data_dir,
  minio_access_key,
  minio_secret_key,
  minio_data_dir,
  minio_init_data_dir,
  ...
}: {
  name = "lobehub";
  services = {
    network-service = {
      image = "alpine";
      container_name = "lobe-network";
      restart = "unless-stopped";
      command = "tail -f /dev/null";
      networks = ["lobe-network"];
    };
    postgresql = {
      image = "paradedb/paradedb:latest-pg17";
      container_name = "lobe-postgres";
      ports = ["5432:5432"];
      volumes = "${pg_data_dir}:/var/lib/postgresql/data";
      restart = "unless-stopped";
      networks = ["lobe-network"];
      environment = {
        POSTGRES_DB = lobe_db_name;
        POSTGRES_PASSWORD = lobe_db_password;
      };
      healthcheck = {
        test = ["CMD-SHELL" "pg_isready -U postgres"];
        interval = "5s";
        timeout = "5s";
        retries = 5;
      };
    };
    redis = {
      image = "redis:7-alpine";
      container_name = "lobe-redis";
      command = "redis-server --save 60 1000 --appendonly yes";
      restart = "unless-stopped";
      networks = ["lobe-network"];
      ports = ["6379:6379"];
      volumes = ["${redis_data_dir}:/data"];
      healthcheck = {
        test = ["CMD" "redis-cli" "ping"];
        interval = "5s";
        timeout = "3s";
        retries = 5;
      };
    };
    rustfs = {
      image = "rustfs/rustfs:latest";
      container_name = "lobe-rustfs";
      network_mode = "service:network-service";
      environment = {
        RUSTFS_CONSOLE_ENABLE = true;
        RUSTFS_ACCESS_KEY = minio_access_key;
        RUSTFS_SECRET_KEY = minio_secret_key;
      };
      volumes = ["${minio_data_dir}:/data"];
      command = [
        "--access-key"
        "$\{RUSTFS_ACCESS_KEY\}"
        "--secret-key"
        "$\{RUSTFS_SECRET_KEY\}"
        "/data"
      ];
      healthcheck = {
        test = [
          "CMD-SHELL"
          "wget -qO- http://localhost:9000/health >/dev/null 2>&1 || exit 1"
        ];
        interval = "5s";
        timeout = "3s";
        retries = 30;
      };
    };
    rustfs-init = {
      image = "minio/mc:latest";
      container_name = "lobe-rustfs-init";
      depends_on.rustfs.condition = "service_healthy";
      volumes = ["${minio_init_data_dir}/bucket.config.json:/bucket.config.json:ro"];
      entrypoint = "/bin/sh";
      command = ''
        -c ' set -eux; echo "S3_ACCESS_KEY=${minio_access_key}, S3_SECRET_KEY=${minio_secret_key}"; mc --version; mc alias set rustfs "http://network-service:9000" "${minio_access_key}" "${minio_secret_key}"; mc ls rustfs || true; mc mb "rustfs/lobe" --ignore-existing; mc admin info rustfs || true; mc anonymous set-json "/bucket.config.json" "rustfs/lobe"; '
      '';
    };
  };
}
