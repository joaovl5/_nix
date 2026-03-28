{
  hm = {
    pkgs,
    # inputs,
    ...
  }: let
    merged_skills = pkgs.symlinkJoin {
      name = "opencode-skills";
      paths = [
        ./skills
        # i don't need those prompts
        # "${inputs.anthropic-skills}/skills"
      ];
    };
  in {
    hybrid-links.links.agents_skills = {
      from = merged_skills;
      to = "~/.agents/skills";
      hybrid = false;
    };
  };
}
