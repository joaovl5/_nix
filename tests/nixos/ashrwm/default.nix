{mylib, ...} @ args:
mylib.tests.mk_test {
  name = "ashrwm";
  python_module_name = "ashrwm";
  nodes.machine = import ./node.nix args;
}
