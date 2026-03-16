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
    home.file.".agents/skills" = {
      source = merged_skills;
      recursive = true;
    };
  };
}
