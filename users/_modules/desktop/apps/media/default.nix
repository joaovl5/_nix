let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    # (import ./obs)
    (import ./stremio)
    # keep-sorted end
  ];
in
  combine_modules modules
