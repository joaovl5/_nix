let
  inherit (import ../../../_lib/modules.nix) combine_modules;
  modules = [
    (import ./langs/js.nix)
    (import ./langs/python.nix)
    (import ./langs/fennel.nix)
    (import ./langs/lua.nix)
    (import ./langs/nix.nix)
    (import ./git.nix)
    (import ./vscode.nix)
  ];
in
  combine_modules modules
