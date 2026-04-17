{
  pkgs,
  inputs,
  lib ? pkgs.lib,
  ...
}: let
  frag_runtime = pkgs.python3Packages.buildPythonPackage {
    pname = "frag";
    version = "0.1.0";
    src = ../../_scripts/frag;
    pyproject = true;

    build-system = with pkgs.python3Packages; [
      setuptools
    ];

    dependencies = with pkgs.python3Packages; [
      cyclopts
      questionary
    ];

    nativeCheckInputs = with pkgs.python3Packages; [
      pytestCheckHook
    ];

    pythonImportsCheck = ["frag"];
  };

  images = import ./images.nix {
    inherit pkgs frag_runtime;
  };

  image_catalog = import ./image_catalog.nix {
    inherit pkgs lib images;
  };

  load_image_helpers = lib.mapAttrs (_key: spec:
    pkgs.writeShellScriptBin spec.loader_name ''
      set -euo pipefail

      docker_bin=${lib.escapeShellArg (lib.getExe' pkgs.docker "docker")}
      image_ref=${lib.escapeShellArg spec.image_ref}

      "$docker_bin" load -i ${spec.image} >/dev/null

      printf '%s\n' "$image_ref"
    '')
  images;

  opencode_json = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    mcp = {
      nixos = {
        command = ["mcp-nixos"];
        enabled = true;
        type = "local";
      };
    };
    plugin = [
      "@gotgenes/opencode-agent-identity"
      "opencode-agent-skills"
    ];
  });

  shared_assets = pkgs.runCommand "frag-shared-assets" {} ''
    shared_root=$out/share/frag/shared-assets

    mkdir -p \
      "$shared_root/.agents" \
      "$shared_root/.config/agents" \
      "$shared_root/.code" \
      "$shared_root/.omp/agent" \
      "$shared_root/.config/opencode/skill" \
      "$shared_root/.config/opencode/plugins"

    cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.agents/skills"
    cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.config/agents/skills"

    cp -r ${../../users/_modules/ai/_prompts/agents} "$shared_root/.code/agents"
    cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.code/skills"
    cp ${../../users/_modules/ai/_prompts/general/system.md} "$shared_root/.code/AGENTS.md"

    cp -r ${../../users/_modules/ai/_prompts/agents} "$shared_root/.omp/agent/agents"
    cp -r ${../../users/_modules/ai/_prompts/skills} "$shared_root/.omp/agent/skills"
    cp ${../../users/_modules/ai/_prompts/general/system.md} "$shared_root/.omp/agent/SYSTEM.md"

    mkdir -p "$shared_root/.config/opencode/skill/agent-browser"
    cp ${opencode_json} "$shared_root/.config/opencode/opencode.json"
    cp -r ${inputs.superpowers + "/skills"} "$shared_root/.config/opencode/skill/superpowers"
    cp ${../../users/_modules/ai/_prompts/skills/agent-browser/SKILL.md} "$shared_root/.config/opencode/skill/agent-browser/SKILL.md"
    cp -r ${inputs.superpowers} "$shared_root/.config/opencode/superpowers"
    cp ${inputs.superpowers + "/.opencode/plugins/superpowers.js"} \
      "$shared_root/.config/opencode/plugins/superpowers.js"
  '';
in
  pkgs.symlinkJoin {
    name = "frag-${frag_runtime.version}";
    paths = [
      frag_runtime
      shared_assets
    ];

    postBuild = ''
      mkdir -p "$out/share/frag" "$out/share/frag/helpers"
      cp ${image_catalog} "$out/share/frag/catalog.json"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: spec: let
          helper = load_image_helpers.${key};
        in ''
          ln -s ${helper}/bin/${spec.loader_name} "$out/share/frag/helpers/${spec.loader_name}"
        '')
        images)}
    '';

    passthru = {
      inherit frag_runtime image_catalog images load_image_helpers;
    };
  }
