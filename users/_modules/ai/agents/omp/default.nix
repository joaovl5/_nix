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
    prompt_agents = ../../_prompts/agents;
    prompt_skills = ../../_prompts/skills;
    system_prompt = ../../_prompts/general/system.md;
  in {
    home.packages = [pkgs.llm-agents.omp];

    home.file = {
      ".omp/agent/mcp.json".source = omp_mcp_config;
      ".omp/agent/SYSTEM.md".source = system_prompt;
      ".omp/agent/agents" = {
        source = prompt_agents;
        recursive = true;
      };
      ".omp/agent/skills" = {
        source = prompt_skills;
        recursive = true;
      };
    };
  };
}
