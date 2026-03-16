{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      koboldcpp
      vllm

      python314Packages.huggingface-hub
    ];
  };
}
