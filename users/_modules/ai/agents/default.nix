let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./opencode)
    (import ./code)
    (import ./omp)
    (import ./hermes)
    (import ./jcode)
  ];
in
  combine_modules modules
