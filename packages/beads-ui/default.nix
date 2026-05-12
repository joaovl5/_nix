{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
  ...
}: let
  version = "0.12.0";
in
  buildNpmPackage {
    pname = "beads-ui";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/beads-ui/-/beads-ui-${version}.tgz";
      hash = "sha512-1SNtPnOm2fl+T7zDk0G1CuNrgyxmWXE2m9IO6xm4e2b+bj/tSd6wRTkq8pgJLP9k4epjTn+WanFtPlI0Blxn3g==";
    };

    nodejs = nodejs_24;
    npmDepsHash = "sha256-Kx9huT4WV+ypwdE0uSlKY4IcBzzmAc0eglBoW5lwU20=";

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;
    npmFlags = ["--omit=dev"];
    npmPackFlags = ["--ignore-scripts"];

    meta = {
      description = "Local UI for Beads";
      homepage = "https://github.com/mantoni/beads-ui";
      license = lib.licenses.mit;
      mainProgram = "bdui";
      platforms = lib.platforms.unix;
    };
  }
