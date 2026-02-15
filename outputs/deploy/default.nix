{
  self,
  deploy-rs,
  ...
}: let
  DEFAULT_SYSTEM = "x86_64-linux";

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
  }: {
    ${host} =
      {
        inherit hostname;
        profiles.system = _d {
          inherit host user;
          sshUser = ssh_user;
        };
      }
      // opts;
  };
in {
  deploy = {
    remoteBuild = false;
    sudo = "run0 --user";

    nodes =
      # _n {
      #   host = "testservervm";
      #   hostname = "192.168.122.169";
      #   ssh_user = "tyrant";
      #   user = "root";
      # } //
      _n {
        host = "tyrant";
        hostname = "192.168.15.13";
        ssh_user = "tyrant";
        user = "root";
      };
  };
}
