let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./_prompts)
    (import ./agents)
    (import ./mcp)
    (import ./runtimes) # ai runtime libs/apps
    # keep-sorted end
  ];
in
  combine_modules modules
