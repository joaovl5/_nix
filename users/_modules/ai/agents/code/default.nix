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
    hybrid-links.links = {
      code_agents = {
        from = prompt_agents;
        to = "~/.code/agents";
      };
      code_skills = {
        from = prompt_skills;
        to = "~/.code/skills";
      };
      code_agents_md = {
        from = system_prompt;
        to = "~/.code/AGENTS.md";
        recursive = false;
      };
    };

    home = {
      packages = [
        (lib.lowPrio pkgs.llm-agents.code)
      ];

      shellAliases.c = "coder";

      file = {
        ".code/config.toml".source = code_config;
      };
    };
  };
}
