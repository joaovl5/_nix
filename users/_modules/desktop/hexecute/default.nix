{
  hm = {
    inputs,
    pkgs,
    ...
  }: {
    hybrid-links.links.hexecute = {
      from = ./config;
      to = "~/.config/hexecute";
    };

    home.packages = [
      inputs.hexecute.packages.${pkgs.system}.default
    ];
  };
}
