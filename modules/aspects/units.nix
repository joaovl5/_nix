{
  den,
  lib,
  ...
}: {
  den.default.includes = [den.aspects.host-units];

  den.aspects.host-units.includes = [
    ({host, ...}: {
      includes = lib.optional ((host.units or []) != []) den.aspects.server;

      nixos.config.my = lib.mkMerge (
        map (unit: {
          "unit.${unit}".enable = lib.mkDefault true;
        }) (host.units or [])
      );
    })
  ];
}
