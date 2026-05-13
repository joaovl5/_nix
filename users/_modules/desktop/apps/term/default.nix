let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./foot)
    (import ./ghostty)
    # keep-sorted end
  ];
in
  combine_modules modules
