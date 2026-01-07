{
  inputs,
  pkgs,
  system,
  ...
}: let
  inherit (inputs) zen-browser;
  version = "twilight";
in {
  imports = [
    zen-browser.homeModules.${version}
  ];

  xdg.mimeApps = let
    value = let
      zen-browser = inputs.zen-browser.packages.${system}.twilight;
    in
      zen-browser.meta.desktopFileName;

    associations = builtins.listToAttrs (map (name: {
        inherit name value;
      }) [
        "application/x-extension-shtml"
        "application/x-extension-xhtml"
        "application/x-extension-html"
        "application/x-extension-xht"
        "application/x-extension-htm"
        "x-scheme-handler/unknown"
        "x-scheme-handler/mailto"
        "x-scheme-handler/chrome"
        "x-scheme-handler/about"
        "x-scheme-handler/https"
        "x-scheme-handler/http"
        "application/xhtml+xml"
        "application/json"
        "text/plain"
        "text/html"
      ]);
  in {
    associations.added = associations;
    defaultApplications = associations;
  };
  programs.zen-browser = {
    enable = true;

    # native messaging support
    nativeMessagingHosts = [pkgs.firefoxpwa];

    profiles."default" = let
      containers = {
        "Personal" = {
          color = "yellow";
          icon = "fingerprint";
          id = 1;
        };
        "Shopping" = {
          color = "green";
          icon = "dollar";
          id = 2;
        };
        "Server" = {
          color = "blue";
          icon = "fence";
          id = 3;
        };
        "Work" = {
          color = "purple";
          icon = "briefcase";
          id = 4;
        };
      };
      spaces = {
        "Personal" = {
          icon = "💤";
          container = containers."Personal".id;
          position = 1000;
          id = "dfbd55c9-38ba-4703-84e2-64aa70d009db";
        };
        "Shopping" = {
          id = "3bfe3559-fbe9-4de6-9b12-f87a6cd0e268";
          container = containers."Shopping".id;
          position = 2000;
          icon = "🛒";
        };
        "Server" = {
          id = "1f614e0d-d94e-44d2-8c5b-a4ddf45e3b65";
          container = containers."Server".id;
          position = 3000;
          icon = "💽";
        };
        "Work" = {
          icon = "💼";
          container = containers."Work".id;
          position = 4000;
          id = "832ad24b-e320-4ea4-abb0-3e2ad72c938f";
        };
      };
      pins = {
        # personal
        "mail" = {
          url = "https://mail.google.com/mail/u/0/#inbox";
          isEssential = true;
          container = containers."Personal".id;
          id = "fea371d8-ba50-4321-9ca7-fb8e725254ba";
        };
        "whatsapp" = {
          url = "https://web.whatsapp.com/";
          isEssential = true;
          container = containers."Personal".id;
          id = "e387b157-4cb4-4ece-8d59-416ebe0742ef";
        };
        # ... todo put others here
      };
    in {
      inherit containers;
      inherit spaces;
      inherit pins;
      containersForce = true; # deletes those not declared
      spacesForce = true;
      # userChrome = ''
      # '';
      settings = {
      };
      extensions.force = true;
      extensions.packages = with inputs.firefox-addons.packages.${system}; [
        ublock-origin
        bitwarden
      ];
      extensions.settings = {
        # some addons have declarative cfg support
        "uBlock0@raymondhill.net".settings = {
          selectedFilterLists = [
            "ublock-filters"
            "ublock-badware"
            "ublock-privacy"
            "ublock-quick-fixes"
            "ublock-unbreak"
            "easylist"
            "adguard-generic"
            "adguard-mobile"
            "easyprivacy"
            "adguard-spyware-url"
            "block-lan"
            "urlhaus-1"
            "curben-phishing"
            "plowe-0"
            "dpollock-0"
            "fanboy-cookiemonster"
            "ublock-cookies-easylist"
            "adguard-cookies"
            "ublock-cookies-adguard"
            "fanboy-social"
            "adguard-social"
            "fanboy-thirdparty_social"
            "fanboy-ai-suggestions"
            "easylist-chat"
            "easylist-newsletters"
            "easylist-notifications"
            "easylist-annoyances"
            "adguard-mobile-app-banners"
            "adguard-other-annoyances"
            "adguard-popup-overlays"
            "adguard-widgets"
            "ublock-annoyances"
            "spa-1"
          ];
        };
      };
      search = {
        force = true; # overwrite
        default = "ddg";
        engines.mynixos = {
          name = "My NixOS";
          urls = [
            {
              template = "https://mynixos.com/search?q={searchTerms}";
              params = [
                {
                  name = "query";
                  value = "searchTerms";
                }
              ];
            }
          ];

          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@nx"]; # aliases must start w/ '@'
        };
        engines.noogle = {
          name = "Noogle";
          urls = [
            {
              template = "https://noogle.dev/q?term={searchTerms}";
              params = [
                {
                  name = "query";
                  value = "searchTerms";
                }
              ];
            }
          ];

          icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = ["@ng"]; # aliases must start w/ '@'
        };
      };
      settings = {
        # any settings from about:config can go here
        browser.tabs.warnOnClose = false;
        browser.download.panel.shown = false;
        extensions.autoDisableScopes = 0; # autoenable extensions
      };
    };

    policies = {
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
  };
}
