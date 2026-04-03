{
  self,
  inputs,
  mylib,
  system,
  ...
} @ args:
mylib.tests.mk_test {
  name = "backup_local";
  python_module_name = "backup_local";

  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit self inputs mylib system;
  };

  nodes.machine = import ./node.nix args;
}
