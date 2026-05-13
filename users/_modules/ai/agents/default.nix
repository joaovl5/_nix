let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./code)
    (import ./jcode)
    (import ./misc)
    (import ./omp)
    (import ./opencode)
    # keep-sorted end
  ];
in
  combine_modules modules
