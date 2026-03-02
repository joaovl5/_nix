{lib, ...}: {
  virtualisation.vmVariant = {
    virtualisation.sharedDirectories = {
      age-key = {
        source = builtins.getEnv "HOME" + "/.age";
        target = "/mnt/age-key";
      };
    };

    system.activationScripts.copy-age-key = lib.stringAfter ["specialfs"] ''
      mkdir -p /root/.age
      cp /mnt/age-key/key.txt /root/.age/key.txt
      chmod 600 /root/.age/key.txt
    '';
  };
}
