let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./claude-code)
    (import ./opencode)
    (import ./codex)
    (import ./crush)
  ];
in
  combine_modules modules
