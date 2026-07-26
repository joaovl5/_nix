{inputs, ...}: let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  local_packages = import ../_packages {inherit pkgs inputs;};
  elisp_autofmt = pkgs.writeShellApplication {
    name = "elisp-autofmt";
    runtimeInputs = [pkgs.emacs pkgs.python3];
    text = ''
      exec python ${pkgs.emacsPackages.elisp-autofmt.src}/elisp-autofmt-cmd.py "$@"
    '';
  };
  main = pkgs.mkShell {
    packages = with pkgs; [
      # keep-sorted start
      alejandra
      basedpyright
      biome
      deadnix
      elisp_autofmt
      fish
      jsonfmt
      just
      kdlfmt
      keep-sorted
      local_packages.rumdl
      local_packages.sane_fnlfmt
      ruff
      shfmt
      sqruff
      statix
      taplo
      yamlfmt
      # keep-sorted end
    ];
  };
in {
  flake.devShells.${system} = {
    inherit main;
    default = main;
  };
}
