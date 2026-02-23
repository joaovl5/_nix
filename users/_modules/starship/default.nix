{
  hm = {lib, ...}: {
    programs.starship = {
      enable = true;
      settings = {
        format = lib.concatStrings [
          "$username"
          "$hostname"
          "$directory"
          "$git_branch"
          "$git_state"
          "$git_status"
          "$nix_shell"
          "$shell"
          "$cmd_duration"
          "$line_break"
          "$python"
          "$character"
        ];

        directory.style = "blue";
        character = {
          success_symbol = "[❯](purple)";
          error_symbol = "[❯](red)";
          vimcmd_symbol = "[❮](green)";
        };
        git_branch = {
          format = "[$branch]($style)";
          style = "bright-black";
        };
        git_status = {
          format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
          style = "cyan";
          conflicted = "";
          untracked = "";
          modified = "";
          staged = "";
          renamed = "";
          deleted = "";
          stashed = "≡";
        };
        git_state = {
          format = ''\([$state( $progress_current/$progress_total)]($style)\) '';
          style = "bright-black";
        };
        nix_shell = {
          format = ''[$symbol$state$name]($style)'';
          style = "cyan";
          heuristic = false;
        };
        shell = {
          disabled = false;
          style = "bright-black";
          format = ''[$indicator]($style)'';
        };
        cmd_duration = {
          format = "[$duration]($style)";
          style = "yellow";
        };
        python = {
          format = "[$virtualenv]($style)";
          style = "bright-black";
          detect_extensions = [];
          detect_files = [];
        };
      };
    };
  };
}
