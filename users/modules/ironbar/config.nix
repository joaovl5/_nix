{pkgs, ...}: let
  progress_script = pkgs.writeShellScript "progress" (builtins.readFile ../../scripts/progress.sh);
  sysinfo_script = pkgs.writeShellScript "sysinfo" (builtins.readFile ../../scripts/sysinfo.sh);
  sysinfo_cmd = "${sysinfo_script} -p ${progress_script}";
  # minimal bar without full addons
  base_bar = {
    position = "top";
    height = 24;
    start = [
      {
        type = "clock";
        format = "%d_%m_%y ┅ %H.%M";
      }
      {
        type = "label";
        name = "sep";
        label = "╱";
      }
      {
        type = "workspaces";
      }
    ];
  };
  # extended bar for primary screen
  full_bar =
    base_bar
    // {
      center = [
        {
          type = "focused";
        }
      ];
      end = [
        {
          type = "label";
          name = "bar-cpu";
          label = "♚ {{2000:${sysinfo_cmd} -c}}";
        }
        {
          type = "label";
          name = "bar-ram";
          label = "◭ {{2000:${sysinfo_cmd} -r}}";
        }
        {
          type = "label";
          name = "bar-disk";
          label = "◔ {{5000:${sysinfo_cmd} -d}}";
        }
      ];
    };
in {
  monitors.DP-4 = full_bar;
  monitors.HDMI-A-2 = base_bar;
}
