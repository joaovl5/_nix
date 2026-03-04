{
  hm = _: {
    programs.claude-code = {
      enable = true;
      rulesDir = ../_prompts/general;
    };
  };
}
