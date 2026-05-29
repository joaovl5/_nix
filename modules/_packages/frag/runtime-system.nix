{
  pkgs,
  modulesPath,
  llm_agents,
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
  services.envfs.enable = true; # handle /usr/bin stuff

  environment.systemPackages = with pkgs; [
    bashInteractive
    cacert
    coreutils
    findutils
    fish
    gnugrep
    gnused
    less
    llm_agents.omp
    llm_agents.claude-code
    llm_agents.oh-my-claudecode
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
    llm_agents.bun
    python314
    jq
    git
  ];

  system.stateVersion = "25.11";
}
