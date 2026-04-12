{
  self,
  lib,
  pkgs,
  ...
}: let
  extra_args = self._utils.hosts.mk_extra_args {inherit pkgs;};
  inherit (extra_args.mylib) meta;
  validated_hosts = meta.evaluation.config.hosts;
  loader = import ../../meta/_loader.nix {inherit lib;};

  recursive_eval = loader {recursive_root = ./meta_modules_fixtures/recursive_root.nix;};
  duplicate_eval = builtins.tryEval (loader {
    parent = ./meta_modules_fixtures/duplicate_parent.nix;
    recursive_root = ./meta_modules_fixtures/recursive_root_dup.nix;
  });
  cycle_eval = builtins.tryEval (loader {cycle = ./meta_modules_fixtures/cycle.nix;});
in {
  meta_modules_eval = assert validated_hosts.lavpc.modules.kanata.enable;
  assert validated_hosts.lavpc.modules.kanata.keyboard_name == "internalKeyboard";
  assert validated_hosts.tyrant.modules.kanata == null;
  assert recursive_eval.order == ["recursive_child" "recursive_root"];
  assert builtins.hasAttr "recursive_child" recursive_eval.registry;
  assert builtins.hasAttr "recursive_root" recursive_eval.registry;
  assert !duplicate_eval.success;
  assert !cycle_eval.success;
    pkgs.runCommand "meta-modules-eval" {} "touch $out";
}
