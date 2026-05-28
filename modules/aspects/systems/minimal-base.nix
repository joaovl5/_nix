{
  den,
  lav,
  ...
}: {
  den.aspects.system-minimal-base = {
    includes = [
      den.aspects.base-security
      den.aspects.service-ntp
      den.aspects.base-console
    ];

    nixos = {
      pkgs,
      config,
      lib,
      inputs,
      mylib,
      system,
      ...
    }: let
      public_data = lav.public {};
      cfg = config.my.nix;
      s = (mylib.use config).secrets;

      ssh_port = 59222;
      ssh_authorized_keys = [
        public_data.ssh_key
      ];

      user = "nixos";
    in {
      my.nix = {
        username = user;
        email = "vieiraleao2005+bootstrap@gmail.com";
        name = "João Pedro";
      };

      networking.hostName = lib.mkForce cfg.hostname;

      users.mutableUsers = false;
      users.users.root = {
        hashedPassword = lib.mkForce null;
        hashedPasswordFile = s.secret_path "password_hash";
      };

      # enable SSH in the boot process
      systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];
      programs = {
        fish.enable = true;
        neovim.enable = true;
        neovim.defaultEditor = true;
        tmux.enable = true;
        git.enable = true;
      };

      services.openssh = {
        enable = true;
        ports = lib.mkForce [ssh_port];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      users.users."${user}" = {
        isNormalUser = true;
        shell = pkgs.fish;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = ssh_authorized_keys;
      };

      system.stateVersion = "25.11";

      environment.systemPackages = with pkgs; [
        neovim
        tmux
        btop
        glances

        # installer deps
        rsync
        git
        inputs.disko.packages.${system}.default
        nixos-facter
      ];
    };
  };
}
