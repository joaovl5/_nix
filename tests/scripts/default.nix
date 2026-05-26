{
  inputs,
  python_pkgs,
  ...
}: let
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
    src = ./.;
    pyproject = true;
    build-system = with python_pkgs; [setuptools];
    dependencies = [nix_machine_protocol];
    doCheck = false;
    pythonImportsCheck = [
      "my_nix_tests"
      "my_nix_tests.vm_bundle_contract"
      "my_nix_tests.backup_local"
      "my_nix_tests.backup_promotion"
      "my_nix_tests.network_namespaces"
      "my_nix_tests.dns"
      "my_nix_tests.wireguard_tunnels"
    ];
  }
