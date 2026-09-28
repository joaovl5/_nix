{inputs, ...}: let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  local_packages = import ../_packages {inherit pkgs inputs;};
  elisp_autofmt = pkgs.writeShellApplication (let
    _src = pkgs.emacsPackages.elisp-autofmt.src;
  in {
    name = "elisp-autofmt";
    runtimeInputs = [pkgs.emacs pkgs.python3];
    text =
      # bash
      ''
        exec python \
          ${_src}/elisp-autofmt-cmd.py \
          "$@"
      '';
  });
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
      local_packages.sane_fnlfmt
      ruff
      rumdl
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
