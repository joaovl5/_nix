{
  hm = _: {
    hybrid-links.links = {
      agents_skills = {
        from = ./skills;
        to = "~/.agents/skills";
      };
      # some use this:
      agents_skills_2 = {
        from = ./skills;
        to = "~/.config/agents/skills";
      };
    };
  };
}
