{
  self,
  inputs,
  mylib,
  system,
  ...
} @ args:
# Single-node backup fixture: machine writes path/custom/postgres snapshots into a
# local filesystem repo so the driver can exercise restore, retention, and
# maintenance behavior without network dependencies.
mylib.tests.mk_test {
  name = "backup_local";
  python_module_name = "backup_local";

  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit self inputs mylib system;
    inherit (args) globals;
  };

  nodes.machine = import ./node.nix args;
}
