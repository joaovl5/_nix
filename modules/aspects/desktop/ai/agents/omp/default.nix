{
  den.aspects.ai.homeManager = {
    inputs,
    system,
    ...
  }: {
    home.packages = [inputs.llm-agents.packages.${system}.omp];
    hybrid-links = {
      links = {
        omp_agents = {
          from = ../../_prompts/agents;
          to = "~/.omp/agent/agents";
        };
        omp_skills = {
          from = ../../_prompts/skills;
          to = "~/.omp/agent/skills";
        };
        omp_system = {
          from = ../../_prompts/general/system.md;
          to = "~/.omp/agent/SYSTEM.md";
          recursive = false;
        };
      };
    };
  };
}
