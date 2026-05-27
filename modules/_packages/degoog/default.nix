{
  lib,
  buildNpmPackage,
  stdenv,
  fetchurl,
  fetchNpmDeps,
  nodejs,
  inputs,
  bun,
  makeWrapper,
  ...
}: let
  src = inputs.degoog-src.outPath;
  upstreamPackage = builtins.fromJSON (builtins.readFile "${src}/package.json");
  patchPackageJson = ''
    node -e 'const fs = require("fs"); const pkg = JSON.parse(fs.readFileSync("package.json", "utf8")); pkg.overrides = { ...(pkg.overrides || {}), ...(pkg.resolutions || {}) }; fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");'
    cp ${./package-lock.json} package-lock.json
  '';
  bunRuntime =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64
    then
      bun.overrideAttrs (old: {
        src = fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${old.version}/bun-linux-x64-baseline.zip";
          hash = "sha256-q+NG9jQUVHzfazW3pkmkkMcouT0AYiYVaSORioTA5Zs=";
        };
        sourceRoot = "bun-linux-x64-baseline";
      })
    else bun;
in
  buildNpmPackage {
    pname = "degoog";
    inherit (upstreamPackage) version;
    inherit src;

    npmDeps = fetchNpmDeps {
      name = "degoog-${upstreamPackage.version}-npm-deps";
      inherit src;
      hash = "sha256-ypDF3iK14mf1npJX1mAMsrkvnuhE0raeMxjc94gelGI=";
      nativeBuildInputs = [nodejs];
      postPatch = patchPackageJson;
    };

    nativeBuildInputs = [
      bunRuntime
      makeWrapper
    ];

    npmBuildScript = "build";

    postPatch = patchPackageJson;

    installPhase = ''
      runHook preInstall

      runtime_root="$out/libexec/degoog"

      mkdir -p "$out/bin" "$runtime_root"
      cp -a package.json package-lock.json node_modules src "$runtime_root/"
      makeWrapper ${bunRuntime}/bin/bun "$out/bin/degoog" \
        --chdir "$runtime_root" \
        --add-flags "run src/server/index.ts"

      runHook postInstall
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck

      cd "$out/libexec/degoog"
      ${bunRuntime}/bin/bun -e 'await import("hono"); await import("./src/server/utils/paths.ts");'
      test -f src/public/app.js
      test -f src/public/settings-page.js
      test -f src/public/themes/degoog-theme/style.css

      runHook postInstallCheck
    '';

    meta = {
      description = "Degoog runtime bundle";
      homepage = "https://github.com/degoog-org/degoog";
      license = lib.licenses.agpl3Only;
      mainProgram = "degoog";
      platforms = lib.platforms.linux;
    };
  }
