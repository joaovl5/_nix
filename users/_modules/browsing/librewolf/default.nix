{
  hm = {
    pkgs,
    lib,
    ...
  } @ args: let
    profile_name = "lav";

    allowed_sites = import ./allowed-sites.nix args;
  in {
    imports = [
      ./xdg.nix
    ];
    programs.librewolf = {
      enable = true;
      settings = import ./settings.nix args;
      policies =
        import ./policies.nix args
        // {
          ExtensionSettings = import ./extensions.nix args;
          Cookies.Allow = allowed_sites;
          EnableTrackingProtection.Exceptions = allowed_sites;
        };
      languagePacks = [
        "en-GB"
        "pt-BR"
      ];
      package = pkgs.librewolf.override {
        # firefox/wrapper.nix args
        extraPrefs = lib.readFile ./prefs.js;
      };
      profiles.${profile_name} = {
        isDefault = true;
        userChrome = ''
          ${lib.readFile ./css/sidebery.css}
        '';
      };
    };
  };
}
