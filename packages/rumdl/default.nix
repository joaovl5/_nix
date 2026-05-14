{
  gitMinimal,
  inputs,
  installShellFiles,
  lib,
  rustPlatform,
  stdenv,
  versionCheckHook,
  ...
}: let
  src = inputs.rumdl-src.outPath;
  tag = inputs.rumdl-src.version or "v0.1.91";
  version = lib.removePrefix "v" tag;
in
  rustPlatform.buildRustPackage {
    pname = "rumdl";
    inherit src version;

    cargoHash = "sha256-OUzZ2CLda5VqNLFX6hzd4+MPXcUPsTWerWravZDJJfU=";

    cargoBuildFlags = [
      "--bin=rumdl"
    ];

    nativeBuildInputs = [
      installShellFiles
    ];

    nativeCheckInputs = [
      gitMinimal
    ];

    __darwinAllowLocalNetworking = true;

    useNextest = true;

    cargoTestFlags = [
      "--lib"
      "--profile"
      "smoke"
    ];

    postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd rumdl \
        --bash <("$out/bin/rumdl" completions bash) \
        --fish <("$out/bin/rumdl" completions fish) \
        --zsh <("$out/bin/rumdl" completions zsh)
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [
      versionCheckHook
    ];

    meta = {
      description = "Markdown linter and formatter";
      homepage = "https://github.com/rvben/rumdl";
      changelog = "https://github.com/rvben/rumdl/blob/${tag}/CHANGELOG.md";
      license = lib.licenses.mit;
      mainProgram = "rumdl";
      platforms = with lib.platforms; unix ++ windows;
    };
  }
