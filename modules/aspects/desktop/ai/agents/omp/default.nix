{lav, ...}: {
  den.aspects.ai.homeManager = {
    inputs,
    pkgs,
    lib,
    ...
  }: let
    mcp_servers = lav.ai.mcp.servers {
      inherit pkgs lib;
    };
    omp_mcp_config = pkgs.writeText "omp-mcp.json" (builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
      mcpServers = mcp_servers;
    });
    prompt_agents = "${inputs.self.outPath}/modules/aspects/desktop/ai/_prompts/agents";
    prompt_skills = "${inputs.self.outPath}/modules/aspects/desktop/ai/_prompts/skills";
    system_prompt = "${inputs.self.outPath}/modules/aspects/desktop/ai/_prompts/general/system.md";
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
