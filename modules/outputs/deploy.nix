{
  globals,
  inputs,
  self,
  ...
}: let
  inherit (inputs) deploy-rs;
  default_system = "x86_64-linux";
  inherit (globals) hosts;

  mk_profile = {
    host,
    sshUser,
    user,
    system ? default_system,
  }: {
    inherit user sshUser;
    path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${host};
  };

  mk_node = {
    host,
    hostname ? host,
    ssh_user ? "root",
    user ? "root",
    ssh_port ? 22,
    fast_connection ? null,
    opts ? {},
    ...
  }:
    {
      inherit hostname;
      profiles.system = mk_profile {
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
    // opts;

  nodes = builtins.mapAttrs (name: host: mk_node (host // {host = name;})) hosts;
in {
  flake.deploy = {
    remoteBuild = false;
    sudo = "run0 --user";

    inherit nodes;
  };
}
