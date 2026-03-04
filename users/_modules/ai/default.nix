let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./claude-code)
    (import ./opencode)
    (import ./codex)
    (import ./crush)
    (import ./mcp)
  ];
in
  combine_modules modules
