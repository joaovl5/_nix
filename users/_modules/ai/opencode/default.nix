{
  nx = {config, ...}: let
    cfg = config.my.nix;
    home_path = config.users.users.${cfg.username}.home;
  in {
    environment.variables."CODEX_HOME" = "${home_path}/.codex";
  };

  hm = {
    inputs,
    lib,
    ...
  }: {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      rules = ''
        ${lib.readFile ../_prompts/general/system.md}
      '';
      skills = "${inputs.anthropic-skills}/skills";
      settings = {
      };
    };
  };
}
