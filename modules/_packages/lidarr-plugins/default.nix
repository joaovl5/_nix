{
  curl,
  dotnetCorePackages,
  fetchurl,
  icu,
  lib,
  makeWrapper,
  openssl,
  sqlite,
  stdenv,
  zlib,
  ...
}:
stdenv.mkDerivation (final_attrs: {
  pname = "lidarr-plugins";
  version = "3.1.2.4938";

  src = fetchurl {
    url = "https://github.com/Lidarr/Lidarr/releases/download/v${final_attrs.version}/Lidarr.develop.${final_attrs.version}.linux-core-x64.tar.gz";
    hash = "sha256-kNOuTXRWrwSr8JeoUkkHaI48JpX4ZLb2NtqWVnO4jaY=";
  };

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/lidarr-${final_attrs.version}"
    cp -R . "$out/share/lidarr-${final_attrs.version}/"

    makeWrapper ${dotnetCorePackages.aspnetcore_8_0}/bin/dotnet "$out/bin/Lidarr" \
      --add-flags "$out/share/lidarr-${final_attrs.version}/Lidarr.dll" \
      --chdir "$out/share/lidarr-${final_attrs.version}" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      curl
      icu
      openssl
      sqlite
      stdenv.cc.cc.lib
      zlib
    ]}

    runHook postInstall
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    test -e "$out/share/lidarr-${final_attrs.version}/UI/index.html"
    test -e "$out/share/lidarr-${final_attrs.version}/Lidarr.Api.V1.dll"

    runHook postInstallCheck
  '';

  meta = {
    description = "Plugin-capable Lidarr develop release";
    homepage = "https://lidarr.audio";
    changelog = "https://github.com/Lidarr/Lidarr/releases/tag/v${final_attrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "Lidarr";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryBytecode];
  };
})
