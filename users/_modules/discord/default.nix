{
  hm = {inputs, ...}: {
    imports = [
      inputs.nixcord.homeModules.nixcord
      ./hm/theming
      ./hm/plugins
    ];

    programs.nixcord = {
      enable = true;
      vesktop.enable = true;
    };
  };
}
