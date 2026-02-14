{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkOption mkIf mkEnableOption types;

  # DEFAULT_FACTER_PATH = "/root/facter.json";

  facter_cfg = config.my_facter;
  # wonky workaround to reading absolute paths, as to avoid using `--impure` explicitly
  # doesnt seem to be working, infinite recursion
  # facter_report_json =
  #   pkgs.runCommand "facter.json" {
  #     nativeBuildInputs = with pkgs; [coreutils];
  #   } ''
  #     mkdir $out
  #     cp -v ${facter_cfg.report_path} $out/facter.json
  #   '';
  # facter_report = builtins.fromJSON facter_report_json;
  # installer tool is pre-configured to use this location (/mnt/root/facter.json)
in {
  options.my_facter = {
    enable = mkEnableOption "Enable nixos-facter" // {default = true;};
    report_path = mkOption {
      description = "Report path for nixos-facter";
      type = types.path;
      default = "${inputs.mysecrets}/facter/${config.my_nix.hostname}.json";
    };
  };

  config = mkIf facter_cfg.enable {
    hardware.facter.reportPath = assert (
      facter_cfg.report_path != "" && facter_cfg.report_path != null
    );
      facter_cfg.report_path;
  };
}
