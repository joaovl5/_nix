{pkgs, ...} @ args: let
  inherit (pkgs) lib;

  test_root = ./nixos;

  test_names =
    lib.attrNames
    (lib.filterAttrs (
      name: type:
        type
        == "directory"
        && !(lib.hasPrefix "_" name) # exclude internal `_`-prefixed dirs
        && builtins.pathExists (test_root + "/${name}/default.nix") # assume a `default.nix` exists therein
    ) (builtins.readDir test_root));
in
  lib.optionalAttrs pkgs.stdenv.isLinux (
    builtins.listToAttrs (map (
        directory_name: let
          test = import (test_root + "/${directory_name}") args;
        in {
          inherit (test) name;
          value = pkgs.testers.runNixOSTest test;
        }
      )
      test_names)
  )
