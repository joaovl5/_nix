{
  hm = {
    inputs,
    lib,
    pkgs,
    ...
  }: let
    # Nixcord creates resources/node_modules/discord_* links for Equicord/OpenASAR.
    # On Linux the real module tree lives at opt/Discord/modules, so bridge it.
    discord_package = (pkgs.callPackage "${inputs.nixcord}/pkgs/discord.nix" {}).overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          if [ -d "$out/opt/Discord/resources" ] && [ -d "$out/opt/Discord/modules" ] && [ ! -e "$out/opt/Discord/resources/modules" ] && [ ! -L "$out/opt/Discord/resources/modules" ]; then
            ln -s ../modules "$out/opt/Discord/resources/modules"
          fi
        '';
    });
  in {
    imports = [
      inputs.nixcord.homeModules.nixcord
      ./hm/theming
      ./hm/plugins
    ];

    programs.nixcord = {
      enable = true;
      vesktop.enable = true;
      discord = {
        package = discord_package;
        vencord.enable = lib.mkForce false;
        equicord.enable = lib.mkForce true;
      };
    };
  };
}
