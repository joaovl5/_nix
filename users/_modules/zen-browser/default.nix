{
  hm = {
    inputs,
    lib,
    pkgs,
    ...
  } @ args: let
    inherit (inputs) zen-browser;
    version = "twilight";
  in {
    imports = [
      zen-browser.homeModules.${version}
      (import ./xdg.nix version)
    ];

    programs.zen-browser = {
      enable = true;

      # native messaging support
      nativeMessagingHosts = [pkgs.firefoxpwa];

      profiles."default" = let
        containers = import ./containers.nix;
        spaces = import ./spaces.nix containers;
        pins = import ./pins.nix containers spaces;
        extension_cfg = import ./extensions.nix args;
        search = import ./search.nix args;
        settings = import ./settings.nix;
        userChrome = lib.readFile ./userChrome.css;
      in {
        inherit containers;
        inherit spaces;
        inherit pins;
        inherit search;
        inherit userChrome;
        inherit settings;
        extensions = {
          # handle extensions
          packages = extension_cfg.extensions;
          inherit (extension_cfg) settings;
          force = true;
        };
        # force overwriting of non-declarative stuff
        containersForce = true;
        spacesForce = true;
      };

      policies = import ./policies.nix;
    };
  };
}
