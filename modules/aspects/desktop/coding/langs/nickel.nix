_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      nickel
      nickel.nls
    ];

    programs.fish.completions.nickel.body =
      # fish
      ''
        nickel gen-completions fish | source
      '';
  };
}
