{
  hm = {
    inputs,
    lib,
    ...
  }: {
    imports = [
      inputs.nixcord.homeModules.nixcord
      ./hm/theming
      ./hm/plugins
    ];

    programs.nixcord = {
      enable = true;
      vesktop.enable = true;
      discord.vencord.enable = lib.mkForce false;
      discord.equicord.enable = lib.mkForce true;
    };
  };
}
