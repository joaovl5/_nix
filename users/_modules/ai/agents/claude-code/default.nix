{
  hm = _: {
    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      memory.source = ../../_prompts/general;

      agentsDir = ../../_prompts/agents;
      skillsDir = ../../_prompts/skills;
    };
  };
}
