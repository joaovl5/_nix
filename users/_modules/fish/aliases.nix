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
      # most shell aliases already handled in shell-aliases module
      # replacing cmds
      # ls -> eza replacements already handled by home-manager
      "cat" = "bat";
      "rm" = "rip";
    };
  };
}
