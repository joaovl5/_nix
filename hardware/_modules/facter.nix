{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption types;
  facter_cfg = config.my_facter;

  # installer tool is pre-configured to use this location (/mnt/root/facter.json)
  DEFAULT_FACTER_PATH = "/root/facter.json";
in {
  options.my_facter = {
    enable = mkEnableOption "Enable nixos-facter" // {default = false;};
    report_path = mkOption {
      description = "Report path for nixos-facter";
      type = types.path;
      default = DEFAULT_FACTER_PATH;
    };
  };

  config = mkIf facter_cfg.enable {
    hardware.facter.reportPath = facter_cfg.report_path;
  };
}
