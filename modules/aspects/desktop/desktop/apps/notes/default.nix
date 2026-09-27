{
  den.aspects.desktop.homeManager = {
    inputs,
    system,
    pkgs,
    ...
  }: {
    home.packages =
      [
        inputs.helix-notes.packages.${system}.default
      ]
      ++ (with pkgs; [
        obsidian
      ]);
  };
}
