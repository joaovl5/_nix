{
  hm = _: {
    programs.lazygit = {
      enable = true;
      settings = {
        gui = {
          tabWidth = 2;
          border = "hidden";
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
      };
    };
  };
}
