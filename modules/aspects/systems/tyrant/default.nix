{den, ...}: {
  den.aspects.system-tyrant = {
    includes = [
      den.aspects.system-server-base
      den.aspects.base-storage-server
    ];

    nixos = {globals, ...}: {
      imports = [
        globals.hosts.tyrant.config
      ];

      my = {
        server.enable = true;
        storage.server.enable = true;
        storage.server.allowed_clients = ["192.168.15.2"];
        host.title_file = ./assets/title.txt;
        host.password.sops_key = "server";
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/backups 0755 root root -"
        "d /var/lib/backups/repos 0755 root root -"
        "d /var/lib/backups/repos/tyrant 0700 root root -"
        "d /var/lib/backups/repos/lavpc 0750 tyrant tyrant -"
      ];
    };
  };
}
