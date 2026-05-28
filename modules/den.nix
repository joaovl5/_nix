{inputs, ...}: {
  imports = [
    inputs.den.flakeModule
    inputs.den.flakeOutputs.apps
    inputs.den.flakeOutputs.checks
    inputs.den.flakeOutputs.devShells
    inputs.den.flakeOutputs.packages
  ];
}
