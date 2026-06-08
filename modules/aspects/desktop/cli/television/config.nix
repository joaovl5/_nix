_: {
  den.aspects.cli.homeManager = {pkgs, ...}: {
    hybrid-links.links.television = {
      from = ./config;
      to = "~/.config/television";
    };
    home.packages = [pkgs.television];
    # programs.television = {
    #   enable = true;
    #   settings = {
    #     tick_rate = 20;
    #     ui = {
    #       input_bar = {
    #         prompt = "$";
    #         position = "bottom";
    #         border_type = "none";
    #         padding.top = 1;
    #         padding.bottom = 1;
    #       };
    #       results_panel.border_type = "none";
    #       preview_panel.border_type = "none";
    #       preview_panel.size = "65";
    #     };
    #   };
    # };
  };
}
