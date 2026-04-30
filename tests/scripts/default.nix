{python_pkgs, ...}:
python_pkgs.buildPythonPackage {
  pname = "my-nix-tests";
  version = "0.1.0";
  src = ./.;
  pyproject = true;
  build-system = with python_pkgs; [setuptools];
  dependencies = [];
  doCheck = false;
  pythonImportsCheck = [
    "my_nix_tests"
    "my_nix_tests.vm_bundle_contract"
    "my_nix_tests.backup_local"
    "my_nix_tests.backup_promotion"
    "my_nix_tests.network_namespaces"
    "my_nix_tests.wireguard_tunnels"
  ];
}
