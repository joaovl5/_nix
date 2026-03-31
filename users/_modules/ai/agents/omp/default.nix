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
    hybrid-links = {
      links = {
        omp_agents = {
          from = prompt_agents;
          to = "~/.omp/agent/agents";
        };
        omp_skills = {
          from = prompt_skills;
          to = "~/.omp/agent/skills";
        };
        omp_system = {
          from = system_prompt;
          to = "~/.omp/agent/SYSTEM.md";
          recursive = false;
        };
      };
    };

    home.file = {
      ".omp/agent/mcp.json".source = omp_mcp_config;
    };
  };
}
