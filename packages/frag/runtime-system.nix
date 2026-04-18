{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/virtualisation/docker-image.nix"
  ];

  documentation = {
    enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  networking.hostName = "frag-runtime";

  users.groups.agent = {};
  users.users.agent = {
    isNormalUser = true;
    group = "agent";
    home = "/home/agent";
    createHome = false;
    shell = pkgs.bashInteractive;
  };

  environment.systemPackages = [
    pkgs.bashInteractive
    pkgs.cacert
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.less
    pkgs.llm-agents.agent-browser
    pkgs.llm-agents.code
    pkgs.llm-agents.omp
    pkgs.llm-agents.opencode
    pkgs.mcp-nixos
    pkgs.procps
    pkgs.nss_wrapper
    pkgs.util-linux
    pkgs.which
  ];

  system.stateVersion = "25.11";
}
