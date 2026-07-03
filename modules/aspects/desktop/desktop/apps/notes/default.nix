{
  den.aspects.desktop.homeManager = {
    inputs,
    system,
    ...
  }: {
    home.packages = [
      inputs.helix-notes.packages.${system}.default
    ];
  };
}
