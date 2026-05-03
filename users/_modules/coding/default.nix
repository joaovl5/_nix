let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./langs)
    (import ./git.nix)
    (import ./vscode.nix)
  ];
in
  combine_modules modules
