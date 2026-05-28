{
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
    inherit globals inputs system;
  };
  host_units = name: globals.hosts.${name}.units or [];
  instantiate_nixos = args:
    inputs.nixpkgs.lib.nixosSystem (
      args
      // {
        inherit system;
        specialArgs = mk_extra_args;
      }
    );
in {
  den.hosts.${system} = {
    lavpc = {
      collisionPolicy = "class-wins";
      instantiate = instantiate_nixos;
      units = host_units "lavpc";
      users.lav.classes = ["homeManager"];
    };
    tyrant = {
      collisionPolicy = "class-wins";
      instantiate = instantiate_nixos;
      units = host_units "tyrant";
    };
    temperance = {
      collisionPolicy = "class-wins";
      instantiate = instantiate_nixos;
      units = host_units "temperance";
    };
    iso = {
      collisionPolicy = "class-wins";
      instantiate = instantiate_nixos;
    };
  };
}
