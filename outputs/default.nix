{self, ...} @ inputs: let
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
  // (import ./channels inputs)
  # ---------------
  # Hosts
  # ---------------
  // (import ./hosts inputs)
  # ---------------
  # Packages
  # ---------------
  // (import ./packages inputs)
  # ---------------
  # Apps
  # ---------------
  // (import ./apps inputs)
  # ---------------
  # Deployment
  # ---------------
  // (import ./deploy inputs)
  # ---------------
  # Checks
  # ---------------
  // (import ./checks inputs)
