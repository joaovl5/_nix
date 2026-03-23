{
  hm = {
    lib,
    # inputs,
    ...
  }: {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      rules = ''
        ${lib.readFile ../_prompts/general/system.md}
      '';
      agents = ../_prompts/agents;
      settings = {
        plugin = [
          "@gotgenes/opencode-agent-identity"
          "opencode-agent-skills"
        ];
      };
    };

    # xdg.configFile = {
    #   "opencode/superpowers" = {
    #     source = inputs.superpowers;
    #     recursive = true;
    #   };
    #
    #   "opencode/plugins/superpowers.js".source =
    #     inputs.superpowers + "/.opencode/plugins/superpowers.js";
    #
    #   "opencode/skills/superpowers" = {
    #     source = inputs.superpowers + "/skills";
    #     recursive = true;
    #   };
    # };
  };
}
