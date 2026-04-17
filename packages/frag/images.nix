{
  pkgs,
  frag_runtime,
  ...
}: {
  main = {
    image_ref = "frag-main:latest";
    loader_name = "load-image-main";
    image = pkgs.dockerTools.buildLayeredImage {
      name = "frag-main";
      tag = "latest";
      contents = [
        pkgs.bashInteractive
        pkgs.busybox
        pkgs.git
        frag_runtime
        pkgs.llm-agents.code
        pkgs.llm-agents.omp
        pkgs.llm-agents.agent-browser
        pkgs.llm-agents.opencode
        pkgs.mcp-nixos
      ];
      config = {
        Env = [
          "HOME=/home/agent"
          "PATH=/bin"
        ];
        WorkingDir = "/home/agent";
      };
    };
  };
}
