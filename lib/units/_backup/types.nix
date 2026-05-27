{lib}: let
  inherit (lib) mkOption;
  t = lib.types;

  mk = mkOption;

  SecretRef = t.submodule {
    options = {
      name = mk {
        type = t.str;
      };
      file = mk {
        type = t.str;
      };
      key = mk {
        type = t.str;
      };
    };
  };

  PayloadPath = t.nullOr (t.submodule {
    options = {
      paths = mk {
        type = t.listOf t.str;
      };
      exclude = mk {
        type = t.listOf t.str;
        default = [];
      };
    };
  });

  PayloadBtrfsSnapshot = t.nullOr (t.submodule {
    options = {
      source_path = mk {
        type = t.str;
      };
      snapshot_path = mk {
        type = t.str;
      };
    };
  });

  PayloadPostgresDump = t.nullOr (t.submodule {
    options = {
      database = mk {
        type = t.str;
      };
    };
  });

  PayloadMysqlDump = t.nullOr (t.submodule {
    options = {
      database = mk {
        type = t.str;
      };
      host = mk {
        type = t.str;
        default = "127.0.0.1";
      };
      port = mk {
        type = t.int;
      };
      username = mk {
        type = t.str;
      };
      password_secret = mk {
        type = SecretRef;
      };
    };
  });

  PayloadCustom = t.nullOr (t.submodule {
    options = {
      command = mk {
        type = t.str;
      };
      stdin_filename = mk {
        type = t.nullOr t.str;
        default = null;
      };
    };
  });
in rec {
  BackupSecretRef = SecretRef;

  BackupDestination = t.submodule {
    options = {
      enable = mk {
        type = t.bool;
        default = false;
      };
      backend = mk {
        type = t.enum ["filesystem" "sftp" "rest" "s3" "rclone"];
      };
      repository_template = mk {
        type = t.str;
      };
      password_secret = mk {
        type = t.nullOr BackupSecretRef;
        default = null;
      };
      environment_secret = mk {
        type = t.nullOr BackupSecretRef;
        default = null;
      };
      extra_options = mk {
        type = t.listOf t.str;
        default = [];
      };
    };
  };

  BackupPolicy = t.submodule {
    options = {
      timerConfig = mk {
        type = t.attrsOf t.str;
      };
      promotion_timerConfig = mk {
        type = t.attrsOf t.str;
      };
      forget_timerConfig = mk {
        type = t.attrsOf t.str;
      };
      prune_timerConfig = mk {
        type = t.attrsOf t.str;
      };
      check_timerConfig = mk {
        type = t.attrsOf t.str;
      };
      promote_to = mk {
        type = t.listOf (t.enum ["B" "C"]);
        default = [];
      };
      forget = mk {
        type = t.listOf t.str;
        default = [];
      };
      check = mk {
        type = t.listOf t.str;
        default = [];
      };
    };
  };

  BackupItem =
    t.addCheck (t.submodule {
      options = {
        enable = mk {
          type = t.bool;
          default = true;
        };
        kind = mk {
          type = t.enum ["path" "btrfs_snapshot" "postgres_dump" "mysql_dump" "custom"];
        };
        policy = mk {
          type = t.str;
        };
        tags = mk {
          type = t.listOf t.str;
          default = [];
        };
        run_as_user = mk {
          type = t.str;
          default = "root";
        };
        prepare = mk {
          type = t.nullOr t.lines;
          default = null;
        };
        cleanup = mk {
          type = t.nullOr t.lines;
          default = null;
        };
        schedule = mk {
          type = t.nullOr (t.attrsOf t.str);
          default = null;
        };
        retention = mk {
          type = t.nullOr (t.listOf t.str);
          default = null;
        };
        promote_to = mk {
          type = t.nullOr (t.listOf (t.enum ["B" "C"]));
          default = null;
        };
        path = mk {
          type = PayloadPath;
          default = null;
        };
        btrfs_snapshot = mk {
          type = PayloadBtrfsSnapshot;
          default = null;
        };
        postgres_dump = mk {
          type = PayloadPostgresDump;
          default = null;
        };
        mysql_dump = mk {
          type = PayloadMysqlDump;
          default = null;
        };
        custom = mk {
          type = PayloadCustom;
          default = null;
        };
      };
    }) (item: let
      payload_fields = [
        "path"
        "btrfs_snapshot"
        "postgres_dump"
        "mysql_dump"
        "custom"
      ];
      populated_payloads = builtins.filter (name: item.${name} != null) payload_fields;
    in
      builtins.length populated_payloads == 1 && populated_payloads == [item.kind]);
}
