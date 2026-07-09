_: {
  den.aspects.ai.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      llama-cpp-vulkan
      python314Packages.huggingface-hub
    ];
  };
}
