{
  hm = {
    inputs,
    pkgs,
    ...
  }: let
    local_packages = import ../../../../../packages {inherit pkgs inputs;};
  in {
    home.packages =
      (with pkgs.llm-agents; [
        goose-cli

        # tools
        beads
      ])
      ++ [
        local_packages.beads-ui
        local_packages.beads-web
        local_packages."mardi-gras"
      ];
  };
}
