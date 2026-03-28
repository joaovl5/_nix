{
  hm = {config, ...}: {
    hybrid-links.links.intellishell_data = {
      from = ./data;
      to = "~/.local/share/intellishell_data";
    };

    programs.intelli-shell = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      settings = {
        data_dir = "${config.xdg.dataHome}/intellishell_data";
        theme = {
          accent = "yellow";
        };
      };
    };
  };
}
