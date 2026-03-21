{pkgs, ...}:
pkgs.python3Packages.buildPythonPackage {
  pname = "vm-launcher";
  version = "0.1.0";
  src = ../../_scripts/vm;
  pyproject = true;
  build-system = with pkgs.python3Packages; [
    setuptools
  ];
  nativeCheckInputs = with pkgs.python3Packages; [
    pytestCheckHook
  ];
  pythonImportsCheck = ["vm_wrapper"];
}
