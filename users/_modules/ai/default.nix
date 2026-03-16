let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./claude-code)
    (import ./_prompts)
    (import ./opencode)
    (import ./mcp)
    (import ./runtimes) # ai runtime libs/apps
  ];
in
  combine_modules modules
