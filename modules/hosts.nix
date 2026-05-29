{
  den,
  globals,
  inputs,
  self,
  ...
}: let
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = self._channels.overlays;
    config.allowUnfree = true;
  };
  mk_extra_args = {
    mylib = import ../lib {
      inherit globals inputs pkgs;
      inherit (pkgs) lib;
    };
    inherit globals inputs;
  };
  host_units = name: globals.hosts.${name}.units or [];
  server_home_user = {
    classes = ["homeManager"];
    aspect = den.aspects.server-home-user;
  };
  instantiate_nixos = args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        inherit system;
        specialArgs = mk_extra_args;
      }
    );
in {
  den.aspects.server-home-user = {};

  den.hosts.${system} = {
    lavpc = {
      instantiate = instantiate_nixos;
      units = host_units "lavpc";
      users.lav.classes = ["homeManager" "hjem"];
    };
    tyrant = {
      instantiate = instantiate_nixos;
      units = host_units "tyrant";
      users.tyrant = server_home_user;
    };
    temperance = {
      instantiate = instantiate_nixos;
      units = host_units "temperance";
      users.temperance = server_home_user;
    };
    iso = {
      instantiate = instantiate_nixos;
    };
  };
}
