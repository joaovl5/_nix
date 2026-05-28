{
  pkgs,
  inputs,
  ...
}:
pkgs.python3Packages.buildPythonPackage {
  pname = "pihole6api";
  version = "0.2.1";
  src = inputs.pihole6api-src;
  pyproject = true;
  doCheck = false;

  # Pi-hole can legitimately operate without session auth and return a valid
  # auth response with no SID/CSRF headers. Drop this patch once upstream
  # supports that response shape directly.
  patches = [./no-session-auth.patch];

  build-system = with pkgs.python3Packages; [
    setuptools
    wheel
  ];

  dependencies = with pkgs.python3Packages; [
    packaging
    requests
  ];
}
