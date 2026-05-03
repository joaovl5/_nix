{
  self,
  inputs,
  mylib,
  system,
  ...
} @ args:
# Two-node backend-less namespace topology. `host` owns my.network_namespaces
# instances and toy confined services; `probe` provides DNS, source observers,
# and denied listeners so the Python driver can prove both allowed and blocked paths.
mylib.tests.mk_test {
  name = "network_namespaces";
  python_module_name = "network_namespaces";

  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit self inputs mylib system;
  };

  nodes = {
    host = import ./host.nix args;
    probe = import ./probe.nix args;
  };
}
