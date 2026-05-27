{
  den,
  inputs,
  self,
  ...
}: {
  flake = {
    inherit inputs self;
    outputs = self.outputs or self;
    supportedSystems = den.systems;
  };
}
