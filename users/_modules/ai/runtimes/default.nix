{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      koboldcpp
      llama-cpp-vulkan

      python314Packages.huggingface-hub
    ];
  };
}
