{
  hm = {
    pkgs,
    lib,
    ...
  }: let
    get = pkg: lib.getExe pkgs.${pkg};
    uvx = pkg: {
      command = "uvx";
      args = [pkg];
    };
    npx = pkg: {
      command = "npx";
      args = ["-y" pkg];
    };
  in {
    programs.mcp = {
      enable = true;
      servers = {
        # nixos docs, etc
        nixos.command = get "mcp-nixos";
        # # repository understanding/compression for LLMs
        # repomix.command = get "repomix";
        # llm memory
        memory = npx "@modelcontextprotocol/server-memory";
        # fetch pages
        fetch = uvx "mcp-server-fetch";
        # search
        duckduckgo-search = uvx "duckduckgo-mcp-server";
      };
    };
  };
}
