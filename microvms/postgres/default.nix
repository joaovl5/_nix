{pkgs, ...}: {
  inherit pkgs;
  config = {
    microvm = {
      hypervisor = "cloud-hypervisor";
      shares = [
        {
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          tag = "ro-store";
          proto = "virtiofs";
        }
      ];
    };
    services.postgresql = {};
  };
}
