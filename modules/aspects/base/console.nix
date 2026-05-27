_: {
  den.aspects.base-console.nixos = {
    pkgs,
    lib,
    config,
    ...
  }: let
    inherit (lib) mkOption types;
    stage1_greeting = ''
      ${lib.readFile ./console/assets/stage1_greeting.txt}

      (stage 1)
    '';
    stage2_greeting = ''
      ${lib.readFile ./console/assets/stage2_greeting.txt}

      (stage 2)
    '';
    system_greeting = ''
      ${config.my_system.title}


    '';
  in {
    options.my_system = {
      title = mkOption {
        description = "System title for console and other tweaks";
        type = types.str;
        default = "<no title>";
      };
    };
    config = {
      console = {
        earlySetup = true;
        font = "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
      };
      boot = {
        initrd.stage1Greeting = stage1_greeting;
        stage2Greeting = stage2_greeting;
      };
      services.getty = {
        greetingLine = system_greeting;
      };
    };
  };
}
