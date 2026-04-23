{
  config,
  mylib,
  pkgs,
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
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            modesetting.enable = true;
            powerManagement.enable = true;
            powerManagement.finegrained = false;
            open = true;
            nvidiaSettings = true;
          };
        };
        services.xserver.videoDrivers = ["nvidia"];
        environment.systemPackages = [pkgs.libnvidia-container];
        virtualisation.docker.rootless = {
          daemon.settings = {
            dns = [
              "1.1.1.1"
              "1.0.0.1"
            ];
            features.cdi = true;
          };
          extraPackages = [pkgs.libnvidia-container];
        };
      }
  )
