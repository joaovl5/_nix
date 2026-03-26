let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./agents)
    (import ./_prompts)
    (import ./mcp)
    (import ./runtimes) # ai runtime libs/apps
  ];
in
  combine_modules modules
