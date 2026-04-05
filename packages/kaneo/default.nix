{
  lib,
  stdenv,
  inputs,
  fetchPnpmDeps,
  nginx,
  nodejs_20,
  pnpm_10,
  pnpmConfigHook,
  python3,
  ...
}:
stdenv.mkDerivation (_final_attrs: let
  src = inputs.kaneo-src.outPath;
  version = inputs.kaneo-src.shortRev or "unstable";
  pname = "kaneo";
in {
  inherit pname version src;

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-PqiRikHsduJYtrqx9BYLV+5PhBzyvTZRy6ySvjqhbY8=";
  };

  nativeBuildInputs = [
    nodejs_20
    pnpm_10
    pnpmConfigHook
    python3
  ];

  buildPhase = ''
    runHook preBuild

    export CI=true
    export VITE_API_URL=KANEO_API_URL
    export VITE_CLIENT_URL=KANEO_CLIENT_URL

    pnpm --filter @kaneo/email build
    pnpm --filter @kaneo/web build
    pnpm --filter @kaneo/api build

    runHook postBuild
  '';

  installPhase = let
    runtime_root = "$out/libexec/kaneo";
  in ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/share/kaneo/web" \
      "${runtime_root}/apps/api" \
      "${runtime_root}/apps/site" \
      "${runtime_root}/apps/web" \
      "${runtime_root}/packages/email" \
      "${runtime_root}/packages/libs" \
      "${runtime_root}/packages/typescript-config"

    cp -a package.json pnpm-lock.yaml pnpm-workspace.yaml "${runtime_root}/"
    cp -a node_modules "${runtime_root}/"
    cp -a apps/api/package.json "${runtime_root}/apps/api/"
    cp -a apps/api/node_modules "${runtime_root}/apps/api/"
    cp -a apps/api/dist "${runtime_root}/apps/api/"
    cp -a apps/api/drizzle "${runtime_root}/apps/api/"
    cp -a apps/site/package.json "${runtime_root}/apps/site/"
    cp -a apps/web/package.json "${runtime_root}/apps/web/"
    cp -a packages/email/package.json "${runtime_root}/packages/email/"
    cp -a packages/email/node_modules "${runtime_root}/packages/email/"
    cp -a packages/email/dist "${runtime_root}/packages/email/"
    cp -a packages/libs/package.json "${runtime_root}/packages/libs/"
    cp -a packages/typescript-config/package.json "${runtime_root}/packages/typescript-config/"
    cp -a apps/web/dist/. "$out/share/kaneo/web/"
    cp apps/web/nginx.conf "$out/share/kaneo/nginx.conf"

    cat > "$out/share/kaneo/replace-web-env.sh" <<'EOF'
    #!${stdenv.shell}
    set -eu

    asset_root="''${KANEO_WEB_ASSET_ROOT:?KANEO_WEB_ASSET_ROOT must be set}"

    escape_sed() {
      printf '%s' "$1" | sed 's/[&#]/\\&/g'
    }

    replace_js_value() {
      key="$1"
      value="$2"
      [ -n "$value" ] || return 0
      escaped_value="$(escape_sed "$value")"

      find "$asset_root" -type f -name '*.js' -exec grep -l "$key" {} \; | \
        xargs -r sed -i "s#''${key}#''${escaped_value}#g"
      find "$asset_root" -type f -name '*.js' -exec grep -l "\"$key\"" {} \; | \
        xargs -r sed -i "s#\"''${key}\"#\"''${escaped_value}\"#g"
    }

    replace_generic_value() {
      key="$1"
      value="$2"
      [ -n "$value" ] || return 0
      escaped_value="$(escape_sed "$value")"

      find "$asset_root" -type f \( -name '*.js' -o -name '*.css' \) -exec grep -l "$key" {} \; | \
        xargs -r sed -i "s#''${key}#''${escaped_value}#g"
    }

    replace_js_value KANEO_API_URL "''${KANEO_API_URL:-}"
    replace_js_value KANEO_CLIENT_URL "''${KANEO_CLIENT_URL:-}"

    env | grep '^KANEO_' | cut -d= -f1 | while IFS= read -r key; do
      case "$key" in
        KANEO_API_URL|KANEO_CLIENT_URL)
          continue
          ;;
      esac

      value="$(printenv "$key")"
      replace_generic_value "$key" "$value"
    done
    EOF

    cat > "$out/bin/kaneo-api" <<'EOF'
    #!${stdenv.shell}
    set -euo pipefail
    exec ${nodejs_20}/bin/node --enable-source-maps --input-type=module -e '
      import { pathToFileURL } from "node:url";
      const mod = await import(pathToFileURL("${runtime_root}/apps/api/dist/index.js"));
      await mod.startServer(Number(process.env.KANEO_API_PORT || 1337));
    ' "$@"
    EOF

    cat > "$out/bin/kaneo-web" <<'EOF'
    #!${stdenv.shell}
    set -euo pipefail
    : "''${KANEO_WEB_RUNTIME_DIR:?KANEO_WEB_RUNTIME_DIR must be set}"
    : "''${KANEO_WEB_CONFIG:?KANEO_WEB_CONFIG must be set}"
    exec ${nginx}/bin/nginx -p "$KANEO_WEB_RUNTIME_DIR" -c "$KANEO_WEB_CONFIG" -g 'daemon off;'
    EOF

    chmod +x "$out/bin/kaneo-api" "$out/bin/kaneo-web" "$out/share/kaneo/replace-web-env.sh"
    patchShebangs "$out/bin" "$out/share/kaneo/replace-web-env.sh"

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    cd "$out/libexec/kaneo/apps/api"
    ${nodejs_20}/bin/node -e 'Promise.all([import("bcrypt"), import("pg"), import("@kaneo/email")]).then(() => process.stdout.write("runtime imports ok\n"))'

    runHook postInstallCheck
  '';

  meta = {
    description = "Kaneo API and web runtime bundle";
    homepage = "https://github.com/usekaneo/kaneo";
    license = lib.licenses.mit;
    mainProgram = "kaneo-api";
    platforms = lib.platforms.linux;
  };
})
