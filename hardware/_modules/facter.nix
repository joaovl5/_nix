{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption types;

  DEFAULT_FACTER_PATH = "/root/facter.json";

  facter_cfg = config.my_facter;

  # wonky workaround to reading absolute paths, as to avoid using `--impure` explicitly
  facter_report_json = pkgs.runCommand "facter.json" {} ''
    mkdir $out
    cp -v ${facter_cfg.report_path} $out/facter.json
  '';
  facter_report = builtins.fromJSON facter_report_json;
  # installer tool is pre-configured to use this location (/mnt/root/facter.json)
in {
  options.my_facter = {
    enable = mkEnableOption "Enable nixos-facter" // {default = true;};
    report_path = mkOption {
      description = "Report path for nixos-facter";
      type = types.path;
      default = DEFAULT_FACTER_PATH;
    };
  };

  config = mkIf facter_cfg.enable {
    # hardware.facter.reportPath = facter_cfg.report_path;
    hardware.facter.report = facter_report;
  };
}
