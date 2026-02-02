{
  pkgs,
  lib,
  config,
  ...
} @ args: let
  inherit (lib) mkOption types;
  greetings = import ./greeter.nix args;
in {
  options.my_system = {
    title = mkOption {
      description = "System title for console and other tweaks";
      type = types.str;
      default = "<no title>";
    };
  };
  config = let
    system_greeting =
      greetings.generate_greeting
      {
        system_title = config.my_system.title;
        show_qr = true; # todo
      };
  in {
    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
    };
    boot = {
      initrd.stage1Greeting = greetings.stage1_greeting;
      stage2Greeting = greetings.stage2_greeting;
    };
    services.getty = {
      greetingLine = system_greeting;
    };
  };
}
