{
  hm = _: {
    /*
    # navigation
    alias .. "cd .."
    alias ... "cd ../.."
    alias .... "cd ../../.."
    alias ..... "cd ../../../.."

    alias grep "grep --color=auto"

    alias q exit
    alias :q exit

    # apps
    abbr n nvim

    abbr t tmux
    abbr t.a "tmux attach"
    abbr t.l "tmux list-sessions"
    abbr t.k "tmux kill-session"

    # replacing/improving cmds
    abbr mv 'mv -v'
    # abbr rm 'rip'
    abbr cp 'cp -v'
    alias ls 'eza --long --classify=auto --icons=always --smart-group -M --git --time-style relative -X'
    alias cat 'bat -P'
    */
    programs.fish.shellAliases = {
      # navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "grep" = "grep --color=auto";
      "q" = "exit";
      ":q" = "exit";
      # replacing cmds
      # ls -> eza replacements already handled by home-manager
      "cat" = "bat";
    };
    programs.fish.shellAbbrs = {
      "mv" = "mv -v";
      "cp" = "cp -v";
      "rm" = "rip";
      # apps
      "n" = "nvim";
      ## systemd
      "s" = "systemctl";
      "s.s" = "systemctl status";
      "s.r" = "systemctl restart";
      "s.S" = "systemctl stop";
      "su" = "systemctl --user";
      "su.s" = "systemctl --user status";
      "su.r" = "systemctl --user restart";
      "su.S" = "systemctl --user stop";
      "j.u" = "journalctl --user -xeu";
      ## tmux
      "t" = "tmux";
      "t.a" = "tmux attach";
      "t.l" = "tmux list-sessions";
      "t.k" = "tmux kill-session";
    };
  };
}
