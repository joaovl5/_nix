{...}: {
  services.timesyncd.enable = false;
  services.ntp.enable = false;
  services.chrony = {
    enable = true;
    enableNTS = true;
    servers = [
      "a.st1.ntp.br"
      "b.st1.ntp.br"
      "c.st1.ntp.br"
      "d.st1.ntp.br"
      "brazil.time.system76.com"
      "time1.mbix.ca"
    ];
  };
}
