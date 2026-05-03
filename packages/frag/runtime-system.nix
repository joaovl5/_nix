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
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    bashInteractive
    cacert
    coreutils
    findutils
    fish
    gnugrep
    gnused
    less
    llm-agents.code
    llm-agents.omp
    llm-agents.claude-code
    llm-agents.oh-my-claudecode
    llm-agents.opencode
    nss_wrapper
    procps
    starship
    tmux
    util-linux
    which
    zellij

    # deps
    perl
    nodejs
    bun
    python314
    jq
    git
  ];

  system.stateVersion = "25.11";
}
