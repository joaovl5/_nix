{
  self,
  deploy-rs,
  globals,
  ...
}: let
  DEFAULT_SYSTEM = "x86_64-linux";
  inherit ((import globals)) hosts;

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
    opts ? {},
    ...
  }: ({
      inherit hostname;
      profiles.system = _d {
        inherit host user;
        sshUser = ssh_user;
      };
    }
    // opts);

  nodes_list =
    map (host: {
      name = host.host;
      value = _n host;
    })
    hosts;
  nodes = builtins.listToAttrs nodes_list;
in {
  deploy = {
    remoteBuild = false;
    sudo = "run0 --user";

    inherit nodes;
  };
}
