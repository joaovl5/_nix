{
  config,
  lib,
  ...
}: let
  inherit (lib) mapAttrs mkEnableOption mkIf mkOption types;

  cfg = config.my."unit.syncthing";
  user = config.my.nix.username;
  src_ignore_patterns = import ../../_modules/storage/src_ignore_patterns.nix;
in {
  options.my."unit.syncthing" = {
    enable = mkEnableOption "server-side Syncthing";

    src_root = mkOption {
      type = types.str;
      default = "/srv/syncthing/src";
      description = "Canonical server-side path for the shared src Syncthing folder.";
    };

    gui_address = mkOption {
      type = types.str;
      default = "127.0.0.1:8384";
      description = "Address for the Syncthing web UI on the storage server.";
    };

    peer_device_ids = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Mapping of Syncthing peer names to device IDs.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.storage.server.enable;
        message = "my.\"unit.syncthing\" requires my.storage.server.enable on this host.";
      }
      {
        assertion = cfg.peer_device_ids != {};
        message = "my.\"unit.syncthing\" requires at least one peer device ID.";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /srv/syncthing 2770 ${user} users - -"
      "d ${cfg.src_root} 2770 ${user} users - -"
    ];

    services.syncthing = {
      enable = true;
      inherit user;
      dataDir = "/srv/syncthing";
      openDefaultPorts = true;
      guiAddress = cfg.gui_address;
      overrideDevices = true;
      overrideFolders = true;
      key = config.sops.secrets.syncthing_tyrant_pem_key.path;
      cert = config.sops.secrets.syncthing_tyrant_pem_cert.path;
      settings = {
        options = {
          localAnnounceEnabled = true;
          relaysEnabled = true;
        };
        devices =
          mapAttrs (name: id: {
            inherit name id;
          })
          cfg.peer_device_ids;
        folders.src = {
          path = cfg.src_root;
          type = "sendreceive";
          label = "src";
          devices = builtins.attrNames cfg.peer_device_ids;
          ignorePatterns = src_ignore_patterns;
        };
      };
    };
  };
}
