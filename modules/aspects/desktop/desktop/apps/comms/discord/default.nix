_: {
  den.aspects.desktop.homeManager = {
    inputs,
    pkgs,
    system,
    ...
  }: {
    home.packages = with pkgs; [
      discordo
      inputs.concord.packages.${system}.default
      goofcord
    ];
  };
}
