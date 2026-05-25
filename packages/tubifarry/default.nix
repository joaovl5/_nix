{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
  ...
}:

stdenvNoCC.mkDerivation (final_attrs: {
  pname = "tubifarry";
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/TypNull/Tubifarry/releases/download/v${final_attrs.version}/Tubifarry-v${final_attrs.version}.net8.0.zip";
    hash = "sha256-ItVcyh7D5AyMfV1k9kcBQsCpF/qr/gJ2xJ37wK5tmY0=";
  };

  nativeBuildInputs = [unzip];

  unpackPhase = ''
    runHook preUnpack

    unzip -q "$src"

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/share/lidarr/plugins/TypNull/Tubifarry"
    cp -R . "$out/share/lidarr/plugins/TypNull/Tubifarry/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -e "$out/share/lidarr/plugins/TypNull/Tubifarry/Lidarr.Plugin.Tubifarry.dll"
    test -e "$out/share/lidarr/plugins/TypNull/Tubifarry/Lidarr.Plugin.Tubifarry.deps.json"

    runHook postInstallCheck
  '';

  meta = {
    description = "Tubifarry plugin for Lidarr";
    homepage = "https://github.com/TypNull/Tubifarry";
    changelog = "https://github.com/TypNull/Tubifarry/releases/tag/v${final_attrs.version}";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryBytecode];
  };
})
