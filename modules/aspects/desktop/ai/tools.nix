_: {
  den.aspects.ai.homeManager = {
    inputs,
    system,
    ...
  }: {
    home.packages = with inputs.llm-agents.packages.${system}; [
      ck
      rtk

      # FIXME: This is breaking `nix flake check` and for some reason cannot
      # detect my "allowUnfree"

      # (qmd.override {cudaSupport = true;})
    ];
  };
}
