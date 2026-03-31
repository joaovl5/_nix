{
  hm = {pkgs, ...}: {
    home.packages = [pkgs.llm-agents.agent-browser];

    home.file.".agent-browser/config.json".text = builtins.toJSON {
      contentBoundaries = true;
      maxOutput = 50000;
    };
  };
}
