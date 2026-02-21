{
  config,
  inputs,
  ...
} @ args: let
  o = import ../../_lib/options args;
  # DEFAULT_FACTER_PATH = "/root/facter.json";
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
in
  o.module "facter" (with o; {
    enable = toggle "Enable nixos-facter" true;
    report_path = opt "Report path for nixos-facter" t.path "${inputs.mysecrets}/facter/${config.my.nix.hostname}.json";
  }) {} (
    opts:
      o.when opts.enable {
        hardware.facter.reportPath = assert (
          opts.report_path != "" && opts.report_path != null
        );
          opts.report_path;
      }
  )
