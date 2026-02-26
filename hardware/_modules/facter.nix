{
  config,
  inputs,
  ...
} @ args: let
  o = import ../../_lib/options args;
in
  o.module "facter" (with o; {
    enable = toggle "Enable nixos-facter" true;
    report_path = opt "Report path for nixos-facter" t.path "${inputs.mysecrets}/facter/${config.my.nix.hostname}.json";
  }) {} (
    opts:
      o.when (opts.enable && (builtins.pathExists opts.report_path)) {
        hardware.facter.reportPath = assert (
          opts.report_path != "" && opts.report_path != null
        );
          opts.report_path;
      }
  )
