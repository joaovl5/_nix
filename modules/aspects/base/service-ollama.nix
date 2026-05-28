_: {
  den.aspects.service-ollama.nixos = {pkgs, ...}: {
    services.ollama = {
      enable = false;
      package = pkgs.ollama-cuda;
      # loadModels = [
      #   "qwen3-vl:2b"
      #   "deepsek-r1:1.5b"
      #   "lfm2.5-thinking:1.2b"
      # ];
    };
  };
}
