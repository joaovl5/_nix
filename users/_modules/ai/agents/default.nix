let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./claude-code)
    (import ./opencode)
    (import ./code)
    (import ./omp)
    (import ./agent-browser)
  ];
in
  combine_modules modules
