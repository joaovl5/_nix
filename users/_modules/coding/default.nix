let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./git.nix)
    (import ./langs)
    # (import ./vscode.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
