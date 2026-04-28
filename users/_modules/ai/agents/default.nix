let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./opencode)
    (import ./code)
    (import ./omp)
    (import ./hermes)
  ];
in
  combine_modules modules
