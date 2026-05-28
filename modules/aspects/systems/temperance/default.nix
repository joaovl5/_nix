{
  den,
  lav,
  ...
}: {
  den.aspects.system-temperance = {
    includes = [den.aspects.system-server-base];

    nixos = {
      lib,
      mylib,
      ...
    }: let
      public_data = lav.public {};
    in {
      imports = [
        (mylib.hosts.host_config "temperance")
      ];

      # TODO: check why these public consts is defined here and at globals
      my = {
        host.title_file = ./assets/title.txt;

        "unit.wireguard" = {
          relay.peer.public_key = public_data.wireguard_key_tyrant;
          extra_peers = [
            {
              publicKey = public_data.wireguard_key_vpn;
              allowedIPs = ["11.1.0.12/32"];
            }
          ];
        };
      };

      # This VPS has no `/dev/kvm`, and the inherited libvirtd daemon can leave
      # `libvirtd.service` failed after its idle shutdown path.
      virtualisation.libvirtd.enable = lib.mkForce false;

      systemd.tmpfiles.rules = [
        "d /var/lib/backups 0755 root root -"
        "d /var/lib/backups/repos 0755 root root -"
        "d /var/lib/backups/repos/tyrant 0750 temperance users -"
      ];
    };
  };
}
