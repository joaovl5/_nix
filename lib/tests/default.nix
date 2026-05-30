{
  inputs,
  pkgs,
  lib,
}: let
  drivers_package = python_pkgs: let
    nix_machine_protocol = python_pkgs.buildPythonPackage {
      pname = "nix-machine-protocol";
      version = "0.1.0";
      src = inputs.nix-machine-protocol-src;
      pyproject = true;
      build-system = with python_pkgs; [hatchling];
      doCheck = false;
      pythonImportsCheck = ["nix_machine_protocol"];
    };
  in
    python_pkgs.buildPythonPackage {
      pname = "my-nix-tests";
      version = "0.1.0";
      src = ../../tests;
      pyproject = true;
      build-system = with python_pkgs; [uv-build];
      dependencies = [nix_machine_protocol];
      doCheck = false;
      pythonImportsCheck = [
        "nixos"
        "common"
        "nixos.backup_local.script"
        "nixos.backup_promotion.script"
        "nixos.network_namespaces.script"
        "nixos.dns.script"
        "nixos.wireguard_tunnels.script"
      ];
    };

  mk_test = args @ {
    python_module_name,
    extraPythonPackages ? (_: []),
    # NixOS test drivers run mypy by default; this repo type-checks drivers separately.
    skipTypeCheck ? true,
    ...
  }: let
    extra_python_packages = extraPythonPackages;
    test_args = removeAttrs args [
      "python_module_name"
      "extraPythonPackages"
      "testScript"
    ];
  in
    test_args
    // {
      inherit skipTypeCheck;
      extraPythonPackages = python_pkgs: [(drivers_package python_pkgs)] ++ extra_python_packages python_pkgs;
      testScript = ''
        from nixos.${python_module_name}.script import run
        run(driver_globals=globals())
      '';
    };
in {
  inherit mk_test drivers_package;
}
