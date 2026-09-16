_: {
  den.aspects.desktop.homeManager = {
    inputs,
    system,
    ...
  }: {
    hybrid-links.links.rio = {
      from = ./config/out;
      to = "~/.config/rio";
    };

    home.packages = [
      inputs.rio.packages.${system}.default
    ];
  };
}
