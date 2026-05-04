{
  globals,
  inputs,
}: let
  inherit (inputs) deploy-rs self;
  DEFAULT_SYSTEM = "x86_64-linux";
  inherit (globals) hosts;

  _d = {
    host,
    sshUser,
    user,
    system ? DEFAULT_SYSTEM,
  }: {
    inherit user sshUser;
    path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${host};
  };

  _n = {
    host,
    hostname ? host,
    ssh_user ? "root",
    user ? "root",
    ssh_port ? 22,
    fast_connection ? null,
    opts ? {},
    ...
  }: ({
      inherit hostname;
      profiles.system = _d {
        inherit host user;
        sshUser = ssh_user;
      };
      sshOpts = ["-p" (toString ssh_port)];
    }
    // (
      if fast_connection == null
      then {}
      else {fastConnection = fast_connection;}
    )
    // opts);

  nodes = builtins.mapAttrs (name: host: _n (host // {host = name;})) hosts;
in {
  deploy = {
    remoteBuild = false;
    sudo = "run0 --user";

    inherit nodes;
  };
}
