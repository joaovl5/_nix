{
  self,
  inputs,
  mylib,
  system,
  ...
} @ args:
mylib.tests.mk_test {
  name = "vm_bundle_contract";
  python_module_name = "vm_bundle_contract";

  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit self inputs mylib system;
    inherit (args) globals;
  };

  nodes.machine = import ./node.nix args;
}
