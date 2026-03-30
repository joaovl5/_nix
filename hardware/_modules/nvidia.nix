{
  config,
  mylib,
  ...
}: let
  o = (mylib.use config).options;
in
  o.module "nvidia" (with o; {
    enable = toggle "Enable nvidia settings" true;
  }) {} (
    opts:
      o.when opts.enable {
        hardware = {
          nvidia-container-toolkit.enable = true;
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.latest;
            modesetting.enable = true;
            powerManagement.enable = true;
            powerManagement.finegrained = false;
            open = false;
            nvidiaSettings = true;
          };
        };
        services.xserver.videoDrivers = ["nvidia"];
      }
  )
