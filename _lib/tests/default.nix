{
  inputs,
  pkgs,
  lib,
}: let
  scripts_package = python_pkgs: import ../../tests/scripts {inherit python_pkgs inputs lib pkgs;};

  mk_test = args @ {
    python_module_name,
    extraPythonPackages ? (_: []),
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
      extraPythonPackages = python_pkgs: [(scripts_package python_pkgs)] ++ extra_python_packages python_pkgs;
      testScript = ''
        from my_nix_tests.${python_module_name} import run
        run(globals())
      '';
    };
in {
  inherit mk_test scripts_package;
}
