{
  hm = {pkgs, ...}: {
    home.packages = [pkgs.llm-agents.hermes-agent];
  };
}
