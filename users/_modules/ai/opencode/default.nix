{
  nx = {config, ...}: let
    cfg = config.my.nix;
    home_path = config.users.users.${cfg.username}.home;
  in {
    environment.variables."CODEX_HOME" = "${home_path}/.codex";
  };

  hm = {lib, ...}: {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      rules = ''
        ${lib.readFile ../_prompts/general/system.md}
      '';
      agents = ../_prompts/agents;
      skills = "${../_prompts/skills}";
      settings = {
      };
    };
  };
}
