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
  cargo_toml = builtins.fromTOML (builtins.readFile "${src}/Cargo.toml");
  version = cargo_toml.package.version;
  tag = inputs.rumdl-src.version or (inputs.rumdl-src.branch or "v${version}");
in
  rustPlatform.buildRustPackage {
    pname = "rumdl";
    inherit src version;

    cargoHash = "sha256-FDwy+6va0nPFoUYwXcy5jeLo7aBq3CMOp0TKVMeGSp8=";

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
