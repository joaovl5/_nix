{
  hm = {
    pkgs,
    lib,
    ...
  }: let
    mcp_servers = import ../../mcp/_servers.nix {
      inherit pkgs lib;
    };
    toml_format = pkgs.formats.toml {};
    code_config = toml_format.generate "code-config.toml" {
      approval_policy = "on-request";
      sandbox_mode = "workspace-write";

      inherit mcp_servers;
    };
    prompt_agents = ../../_prompts/agents;
    prompt_skills = ../../_prompts/skills;
    system_prompt = ../../_prompts/general/system.md;
  in {
    home = {
      packages = [
        (lib.lowPrio pkgs.llm-agents.code)
      ];

      shellAliases.c = "coder";

      file = {
        ".code/config.toml".source = code_config;

        ".code/AGENTS.md".source = system_prompt;
        ".code/agents" = {
          source = prompt_agents;
          recursive = true;
        };
        ".code/skills" = {
          source = prompt_skills;
          recursive = true;
        };

        ".codex/AGENTS.md".source = system_prompt;
        ".codex/agents" = {
          source = prompt_agents;
          recursive = true;
        };
        ".codex/skills" = {
          source = prompt_skills;
          recursive = true;
        };
      };
    };
  };
}
