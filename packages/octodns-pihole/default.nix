{
  pkgs,
  inputs,
  pihole6api,
  ...
}:
pkgs.python3Packages.buildPythonPackage {
  pname = "octodns-pihole";
  version = "0.1.0";
  src = inputs.octodns-pihole-src;
  pyproject = true;
  doCheck = false;

  build-system = with pkgs.python3Packages; [
    setuptools
    wheel
  ];

  dependencies = with pkgs.python3Packages; [
    pkgs.octodns
    packaging
    requests
    pihole6api
  ];
}
