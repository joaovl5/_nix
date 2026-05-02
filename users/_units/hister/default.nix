{
  mylib,
  config,
  globals,
  inputs,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  t = lib.types;
  hister_pkg = inputs.hister.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default;
  compact_null_attrs = attrs: lib.filterAttrs (_: value: value != null) attrs;
in
  o.module "unit.hister" (with o; {
    enable = toggle "Enable Hister web history service" false;
    data_dir = opt "Directory for Hister state data." t.str "/var/lib/hister";
    endpoint = u.endpoint {
      port = 4433;
      target = "hister";
    };
    indexer = {
      directories = opt "Directories for Hister to index." (t.listOf t.str) ["/srv/shared"];
      max_file_size_mb = opt "Maximum file size in MiB for indexing." t.int 25;
    };
    semantic_search = {
      enable = toggle "Enable Hister semantic search" false;
      embedding_endpoint = optional "Semantic search embedding endpoint" t.str {};
      embedding_model = optional "Semantic search embedding model" t.str {};
      dimensions = optional "Semantic search embedding dimensions" t.int {};
    };
  }) {
    imports = _: [inputs.hister.nixosModules.hister];
  } (opts:
    o.when opts.enable (let
      base_url = "https://${opts.endpoint.target}.${globals.dns.tld}";
      semantic_search = compact_null_attrs {
        inherit (opts.semantic_search) enable;
        inherit (opts.semantic_search) embedding_endpoint;
        inherit (opts.semantic_search) embedding_model;
        inherit (opts.semantic_search) dimensions;
      };
    in {
      sops.secrets.hister_access_token = s.mk_secret "${s.dir}/hister.yaml" "access_token" {};

      my.vhosts.hister = {
        inherit (opts.endpoint) target sources;
      };

      my."unit.hister".backup.items.state = {
        kind = "path";
        policy = "sensitive_data";
        path.paths = [opts.data_dir];
      };

      systemd.tmpfiles.rules = [
        "d ${opts.data_dir} 0750 hister users - -"
        "d /run/hister 0700 root root - -"
      ];

      systemd.services.hister-prepare-env = {
        description = "Prepare Hister environment file";
        before = ["hister.service"];
        requiredBy = ["hister.service"];
        partOf = ["hister.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "hister-prepare-env" ''
            set -euo pipefail
            install -d -m 0700 -o root -g root /run/hister
            token="$(cat ${s.secret_path "hister_access_token"})"
            if [ -z "$token" ]; then
              echo "Hister access token secret is empty" >&2
              exit 1
            fi
            printf 'HISTER__APP__ACCESS_TOKEN=%s\n' "$token" > /run/hister/env
            chmod 0400 /run/hister/env
            chown root:root /run/hister/env
          '';
        };
      };

      services.hister = {
        enable = true;
        package = hister_pkg;
        user = "hister";
        group = "users";
        inherit (opts.endpoint) port;
        dataDir = opts.data_dir;
        environmentFile = "/run/hister/env";
        settings = {
          server = {
            address = "127.0.0.1:${toString opts.endpoint.port}";
            inherit base_url;
            database = "db.sqlite3";
          };
          indexer = {
            directories = map (path: {inherit path;}) opts.indexer.directories;
            inherit (opts.indexer) max_file_size_mb;
          };
          inherit semantic_search;
        };
      };
    }))
