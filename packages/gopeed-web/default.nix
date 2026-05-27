{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
  ...
}:
stdenvNoCC.mkDerivation (final_attrs: {
  pname = "gopeed-web";
  version = "1.9.3";

  src = fetchurl {
    url = "https://github.com/GopeedLab/gopeed/releases/download/v${final_attrs.version}/gopeed-web-v${final_attrs.version}-linux-amd64.zip";
    hash = "sha256-UkRMhv+1FSyJ0cOjsHQoXE723T2rydSuCXzHA+D6PhU=";
  };

  nativeBuildInputs = [unzip];

  unpackPhase = ''
    runHook preUnpack

    unzip -q "$src"

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 "gopeed-web-v${final_attrs.version}-linux-amd64/gopeed" "$out/bin/gopeed-web"

    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/gopeed-web" -h >/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Headless Gopeed Web download service";
    homepage = "https://github.com/GopeedLab/gopeed";
    license = lib.licenses.gpl3Only;
    mainProgram = "gopeed-web";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
