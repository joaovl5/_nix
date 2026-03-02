{pkgs, ...} @ args: _: {
  name = "test_vm";

  node.pkgsReadOnly = false;
  node.specialArgs = with args; {
    inherit
      self
      inputs
      mylib
      system
      ;
  };
  nodes.machine = import ./node.nix args;

  testScript = pkgs.lib.readFile ./test.py;
}
