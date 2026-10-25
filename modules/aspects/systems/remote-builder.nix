{
  den.aspects.tyrant-nix-builder.nixos = {
    globals,
    pkgs,
    ...
  }: {
    nix.settings.trusted-users = ["nix-builder"];

    users = {
      groups.nix-builder = {};
      users.nix-builder = {
        isSystemUser = true;
        group = "nix-builder";
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [
          globals.hosts.tyrant.nix_builder.public_key
        ];
      };
    };
  };

  den.aspects.lavpc-remote-builder.nixos = {
    config,
    globals,
    lib,
    mylib,
    ...
  }: let
    s = (mylib.use config).secrets;
    builder = globals.hosts.tyrant.nix_builder;
    secret_name = "lavpc_tyrant_nix_builder";
  in {
    sops.secrets.${secret_name} = s.mk_secret "${s.dir}/ssh_keys.yaml" secret_name {};

    # sshconfig
    programs.ssh.extraConfig = ''
      Host tyrant-builder
        HostName ${globals.hosts.tyrant.host_ip}
        Port ${toString globals.hosts.tyrant.ssh_port}
        IdentitiesOnly yes
    '';

    nix = {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = "tyrant-builder";
          protocol = "ssh-ng";
          sshUser = "nix-builder";
          sshKey = config.sops.secrets.${secret_name}.path;
          systems = ["x86_64-linux"];
          maxJobs = 6;
          speedFactor = 1;
          supportedFeatures = ["benchmark" "big-parallel" "nixos-test"];
          publicHostKey = builder.host_key;
        }
      ];
      settings = {
        max-jobs = lib.mkForce 0;
        builders-use-substitutes = true;
      };
    };
  };
}
