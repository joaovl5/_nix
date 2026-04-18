{
  pkgs,
  frag_runtime,
  lib ? pkgs.lib,
  ...
}: let
  runtimeFrag = pkgs.python3Packages.buildPythonPackage {
    pname = "frag-runtime";
    inherit (frag_runtime) version;
    src = ../../_scripts/frag;
    pyproject = true;

    build-system = with pkgs.python3Packages; [
      setuptools
    ];

    dependencies = with pkgs.python3Packages; [
      cyclopts
      questionary
    ];

    doCheck = false;
    pythonImportsCheck = ["frag"];
  };

  runtimeSystem = import "${pkgs.path}/nixos" {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs = {inherit pkgs;};
    configuration = {...}: {
      imports = [./runtime-system.nix];
      environment.systemPackages = [runtimeFrag];
    };
  };

  runtimeSystemPath = runtimeSystem.config.system.path;
  runtimeTarball = runtimeSystem.config.system.build.tarball;
  runtimeRootfs =
    pkgs.runCommand "frag-runtime-rootfs.tar" {
      nativeBuildInputs = [
        pkgs.gnutar
        pkgs.xz
      ];
    } ''
      mkdir -p "$TMPDIR/runtime-root"
      tar -xJf ${runtimeTarball}/tarball/*.tar.xz -C "$TMPDIR/runtime-root"

      rm -rf "$TMPDIR/runtime-root/home/agent" "$TMPDIR/runtime-root/sw"
      mkdir -p "$TMPDIR/runtime-root/home" "$TMPDIR/runtime-root/state/profile/home"
      ln -s /state/profile/home "$TMPDIR/runtime-root/home/agent"
      ln -s ${runtimeSystemPath} "$TMPDIR/runtime-root/sw"

      tar -cf "$out" -C "$TMPDIR/runtime-root" .
    '';

  image_ref = "frag-main:${builtins.substring 0 32 (builtins.baseNameOf (toString runtimeRootfs))}";
  loader_name = "load-image-main";
in {
  main = {
    inherit image_ref loader_name;
    artifact = runtimeRootfs;
    bootstrap_entrypoint = "/sw/bin/frag-bootstrap";
    loader_helper = pkgs.writeShellScriptBin loader_name ''
      set -euo pipefail

      docker_bin=${lib.escapeShellArg (lib.getExe' pkgs.docker "docker")}
      image_ref=${lib.escapeShellArg image_ref}
      runtime_rootfs=${lib.escapeShellArg runtimeRootfs}

      "$docker_bin" image rm -f "$image_ref" >/dev/null 2>&1 || true
      "$docker_bin" import \
        --change 'CMD ["/init"]' \
        --change 'ENV HOME=/home/agent' \
        --change 'ENV PATH=/sw/bin:/bin' \
        --change 'ENV USER=agent' \
        --change 'WORKDIR /home/agent' \
        "$runtime_rootfs" \
        "$image_ref" >/dev/null

      printf '%s\n' "$image_ref"
    '';
  };
}
