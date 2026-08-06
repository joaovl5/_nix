_: {
  den.aspects.ai.homeManager = {
    inputs,
    system,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      inputs.bonsai-llama-pkg.packages.${system}.default
      python314Packages.huggingface-hub
    ];
  };
}
