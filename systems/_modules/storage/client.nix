{
  config,
  mylib,
  ...
}: let
  my = mylib.use config;
  o = my.options;

  cfg = config.my.storage.client;
  inherit (config.my.nix) username;
in
  o.module "storage" (with o; {
    client = {
      enable = toggle "Enable shared storage NFS client" false;
      shared_dirname = opt "Home-relative directory name for the shared storage mount point." t.str ".shared";
      mount_point = opt "Absolute path where the shared NFS tree is mounted." t.str "/home/${username}/${cfg.shared_dirname}";
      server = opt "Hostname or address of the shared storage server." t.str "tyrant";
      export_path = opt "Exported NFS path on the storage server." t.str "/srv/shared";
      automount_timeout = opt "Idle timeout before the automounted shared tree is unmounted." t.str "10min";
    };
  }) {} (opts:
    o.when opts.client.enable {
      boot.supportedFilesystems = ["nfs"];

      systemd.tmpfiles.rules = [
        "d ${opts.client.mount_point} 0755 ${username} users - -"
      ];

      fileSystems.${opts.client.mount_point} = {
        device = "${opts.client.server}:${opts.client.export_path}";
        fsType = "nfs";
        options = [
          "noauto"
          "nofail"
          "_netdev"
          "nfsvers=4.2"
          "x-systemd.automount"
          "x-systemd.idle-timeout=${opts.client.automount_timeout}"
        ];
      };
    })
