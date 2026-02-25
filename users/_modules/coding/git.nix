{
  hm = {
    nixos_config,
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = nixos_config.my.nix;

    signing_key_path = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
  in {
    # TODO: ^1 add merging stuff
    programs.git = {
      enable = true;
      signing = {
        signByDefault = true;
      };
      settings = {
        init = {
          defaultBranch = "main";
        };
        checkout = {
          workers = 0; # use all cores
        };
        color = {
          ui = "auto";
        };
        diff = {
          external = lib.getExe pkgs.difftastic;
          algorithm = "histogram";
          colorMoved = true;
        };
        gpg = {
          format = "ssh";
        };
        push = {
          autoSetupRemote = true;
        };
        user = {
          inherit (cfg) email name;
          signingKey = signing_key_path;
        };
        rerere = {
          enabled = true;
          autoupdate = true;
        };
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;

      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
      };
    };

    home.shellAliases = {
      ",ga" = "git";
      ",ga." = "git add .";
      ",gC" = "git commit";
      ",gc" = "git commit -m";
      ",gs" = "git status";
      ",gP" = "git push";
      ",gp" = "git pull";
      ",gl" = "git log";
      ",gd" = "git diff";
    };

    home.packages = with pkgs; [
      prek
    ];
  };
}
