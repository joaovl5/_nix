{pkgs, ...} @ args: let
  inherit (pkgs) lib;

  test_names =
    lib.attrNames
    (lib.filterAttrs (
      name: type:
        type
        == "directory"
        && name != "scripts" # exclude scripts python package
        && !(lib.hasPrefix "_" name) # exclude other internal `_`-prefixed dirs
        && builtins.pathExists (./. + "/${name}/default.nix") # assume a `default.nix` exists therein
    ) (builtins.readDir ./.));
in
  lib.optionalAttrs pkgs.stdenv.isLinux (
    builtins.listToAttrs (map (
        directory_name: let
          test = import (./. + "/${directory_name}") args;
        in {
          inherit (test) name;
          value = pkgs.testers.runNixOSTest test;
        }
      )
      test_names)
  )
