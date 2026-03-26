{
  hm = {
    pkgs,
    lib,
    ...
  }: let
    mcp_servers = import ../../mcp/_servers.nix {
      inherit pkgs lib;
    };
    omp_mcp_config = pkgs.writeText "omp-mcp.json" (builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
      mcpServers = mcp_servers;
    });
    agent_browser_skill = ../../_prompts/skills/agent-browser/SKILL.md;
  in {
    home.packages = [pkgs.llm-agents.omp];

    home.file = {
      ".omp/agent/mcp.json".source = omp_mcp_config;
      ".omp/agent/skills/agent-browser/SKILL.md".source = agent_browser_skill;
    };
  };
}
