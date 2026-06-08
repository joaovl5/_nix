_: {
  den.aspects.ai.homeManager = {
    inputs,
    system,
    ...
  }: {
    home.packages = with inputs.llm-agents.packages.${system}; [
      (qmd.override {cudaSupport = true;})
      ck
      rtk
    ];
  };
}
