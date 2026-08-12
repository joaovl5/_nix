_: {
  den.aspects.desktop.nixos = _: {
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
  den.aspects.desktop.homeManager = _: {
    programs.distrobox = {
      enable = true;
      enableSystemdUnit = true;
      settings = {
        container_always_pull = "1";
        non_interactive = "1";
        skip_workdir = "0";
      };
      containers.ubuntu = {
        additional_packages = "bat eza tmux fzf build-essential git python3 python3-pip python3-venv";
        additional_flags = "--env CUDA_HOME=/usr/local/cuda";
        entry = true;
        image = "docker.io/nvidia/cuda:13.2.0-devel-ubuntu24.04";
        nvidia = true;
        replace = true;
      };
    };
  };
}
