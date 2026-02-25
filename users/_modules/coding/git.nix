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
    programs = {
      delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          light = false;
          line-numbers = true;
          navigate = true;
          side-by-side = true;
        };
      };
      git = {
        enable = true;
        settings = {
          checkout = {workers = 0;};
          color = {ui = "auto";};
          diff = {
            algorithm = "histogram";
            colorMoved = true;
            external = lib.getExe pkgs.difftastic;
          };
          gpg = {format = "ssh";};
          init = {defaultBranch = "main";};
          push = {autoSetupRemote = true;};
          merge.mergiraf = {
            name = "mergiraf";
            driver = "${lib.getExe pkgs.mergiraf} merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
          };
          rerere = {
            autoupdate = true;
            enabled = true;
          };
          user = {
            inherit (cfg) email name;
            signingKey = signing_key_path;
          };
        };
        attributes = [
          "* merge=mergiraf"
        ];

        signing = {signByDefault = true;};
      };
      git-cliff = {
        enable = true;
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
      cocogitto
    ];
  };
}
