let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./media)
    (import ./browsing)
    (import ./discord)
    (import ./gaming)
    (import ./term)
    (import ./editor)
  ];
in
  combine_modules modules
