let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./browsing)
    (import ./discord)
    (import ./editor)
    (import ./gaming)
    (import ./media)
    (import ./term)
    # keep-sorted end
  ];
in
  combine_modules modules
