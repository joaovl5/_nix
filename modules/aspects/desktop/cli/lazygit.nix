_: {
  den.aspects.cli.homeManager = {
    programs.lazygit = {
      enable = true;
      settings = {
        promptToReturnFromSubprocess = false;
        gui = {
          tabWidth = 2;
          showCommandLog = false;
          screenMode = "half";
          border = "hidden";
          nerdFontsVersion = "3";
          spinner.frames = [
            "🌑"
            "🌘"
            "🌗"
            "🌖"
            "🌕"
            "🌔"
            "🌓"
            "🌒"
          ];
        };
        git = {
          overrideGpg = true;
          pagers = [
            {
              colorArg = "always";
              useExternalDiffGitConfig = true;
            }
          ];
          commit = {
            signOff = true;
          };
          ignoreWhitespaceInDiffVIew = true;
          log.order = "date-order";
        };
        customCommands = [
          {
            key = "C";
            context = "files";
            command = "cz c";
            description = "Commitizen";
            output = "terminal";
            outputTitle = "Commitizen";
          }
        ];
      };
    };
  };
}
