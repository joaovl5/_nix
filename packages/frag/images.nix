{
  pkgs,
  frag_runtime,
  lib ? pkgs.lib,
  ...
}: let
  runtimeFrag = frag_runtime.overridePythonAttrs (old: {
    # Keep the runtime image on the shared frag derivation while preserving
    # the leaner runtime dependency set used for image assembly.
    pname = "frag-runtime";
    dependencies = lib.filter (pkg: lib.getName pkg != "rich") (
      old.dependencies or frag_runtime.dependencies
    );
    doCheck = false;
  });

  runtimeSystem = import "${pkgs.path}/nixos" {
    system = null;
    configuration = {modulesPath, ...}: {
      imports = [
        ./runtime-system.nix
        "${modulesPath}/misc/nixpkgs/read-only.nix"
      ];
      nixpkgs.pkgs = pkgs;
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

  packaged_image_identity_label = "dev.frag.packaged-runtime-rootfs";
  packaged_image_change_prefix = [
    ''CMD ["/init"]''
    "ENV HOME=/home/agent"
    "ENV PATH=/sw/bin:/bin"
    "ENV USER=agent"
    "WORKDIR /home/agent"
  ];
  packaged_image_identity = builtins.hashString "sha256" (
    builtins.toJSON [
      (toString runtimeRootfs)
      (packaged_image_change_prefix
        ++ [
          "LABEL ${packaged_image_identity_label}=<packaged-image-identity>"
        ])
    ]
  );
  packaged_image_changes =
    packaged_image_change_prefix
    ++ [
      "LABEL ${packaged_image_identity_label}=${packaged_image_identity}"
    ];
  loader_name = "load-image-main";
  image_ref = "frag-main:${builtins.substring 0 32 packaged_image_identity}";
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
            packaged_image_identity=${lib.escapeShellArg packaged_image_identity}
            packaged_image_identity_label=${lib.escapeShellArg packaged_image_identity_label}

            if current_packaged_image_identity="$(
              "$docker_bin" image inspect \
                --format "{{ index .Config.Labels \"$packaged_image_identity_label\" }}" \
                "$image_ref" 2>/dev/null
            )"; then
              if [ "$current_packaged_image_identity" = "$packaged_image_identity" ]; then
                printf '%s\n' "$image_ref"
                exit 0
              fi
            fi

            "$docker_bin" image rm -f "$image_ref" >/dev/null 2>&1 || true
            "$docker_bin" import \
      ${lib.concatMapStringsSep "" (change: "        --change ${lib.escapeShellArg change} \\\n") packaged_image_changes}        "$runtime_rootfs" \
              "$image_ref" >/dev/null

            printf '%s\n' "$image_ref"
    '';
  };
}
