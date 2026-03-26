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
    agent_browser_skill = ../../_prompts/skills/agent-browser/SKILL.md;
  in {
    home = {
      packages = [pkgs.llm-agents.code];

      shellAliases.c = "coder";

      file = {
        ".code/config.toml".source = code_config;

        ".code/skills/agent-browser/SKILL.md".source = agent_browser_skill;
        ".codex/skills/agent-browser/SKILL.md".source = agent_browser_skill;
      };
    };
  };
}
