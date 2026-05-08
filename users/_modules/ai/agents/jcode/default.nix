{
  hm = {
    inputs,
    system,
    ...
  }: {
    hybrid-links.links.jcode_config = {
      from = ./config.toml;
      to = "~/.jcode/config.toml";
      recursive = false;
    };

    home.packages = [inputs.jcode.packages.${system}.default];
  };
}
