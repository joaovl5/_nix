{
  globals,
  inputs,
}: let
  inherit (inputs) self;
  context = {inherit globals inputs;};
  SYSTEMS = ["x86_64-linux"];
in
  {
    inherit self inputs;

    ## supported systems
    supportedSystems = SYSTEMS;
  }
  # ---------------
  # Channels
  # ---------------
  // (import ./channels context)
  # ---------------
  # Hosts
  # ---------------
  // (import ./hosts context)
  # ---------------
  # Packages
  # ---------------
  // (import ./packages context)
  # ---------------
  # Apps
  # ---------------
  // (import ./apps context)
  # ---------------
  # Deployment
  # ---------------
  // (import ./deploy context)
  # ---------------
  # Checks
  # ---------------
  // (import ./checks context)
