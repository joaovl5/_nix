{den, ...}: {
  den.hosts.aarch64-darwin.essos = {};
  den.aspects.essos.includes = [
    den.aspects.hardware-essos
    den.aspects.system-essos
  ];
}
