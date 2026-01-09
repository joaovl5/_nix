{
  hm = {...}: {
    programs.eza = {
      enable = true;
      git = true;
      icons = "always";
      colors = "always";
      extraOptions = [
        "--long"
        "--classify=auto"
        "--smart-group"
        "--time-style=relative"
        "-X"
        "-M"
      ];
    };
  };
}
