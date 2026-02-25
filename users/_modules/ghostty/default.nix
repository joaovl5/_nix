{
  hm = {pkgs, ...}: {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      systemd.enable = true;

      settings = {
        font-size = 15;
        font-family = "FiraCode Nerd Font Med";

        theme = "Aura";
        window-theme = "dark";
        window-padding-x = 10;
        window-padding-y = 15;

        scrollback-limit = 100000;

        window-padding-balance = true;
        confirm-close-surface = false;
        mouse-hide-while-typing = true;

        quit-after-last-window-closed = false;

        cursor-style = "underline";

        shell-integration = "detect";
        shell-integration-features = [
          "sudo"
          "cursor"
          "title"
          "ssh-env"
          "ssh-terminfo"
        ];

        # gtk-only
        gtk-toolbar-style = "flat";
        gtk-tabs-location = "bottom";
        gtk-wide-tabs = false;
        gtk-titlebar = false;
        # macos-only
        macos-window-buttons = "hidden";
        macos-secure-input-indication = true;
        macos-icon = "retro";

        keybind = [
          "alt+q=close_surface"
          "alt+shift+0=reload_config"
          "alt+equal=increase_font_size:1"
          "alt+minus=decrease_font_size:1"
          "alt+enter=new_tab"
          "alt+bracket_left=scroll_page_up"
          "alt+bracket_right=scroll_page_down"
          "alt+h=next_tab"
          "alt+l=previous_tab"
          "alt+c=copy_to_clipboard"
          "alt+v=paste_from_clipboard"
        ];
      };
    };
  };
}
