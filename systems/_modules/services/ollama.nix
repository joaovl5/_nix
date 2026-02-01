{pkgs, ...}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    loadModels = [
      "qwen3-vl:2b"
      "deepsek-r1:1.5b"
      "lfm2.5-thinking:1.2b"
    ];
  };
}
