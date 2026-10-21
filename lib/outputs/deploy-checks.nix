{
  self,
  pkgs,
  ...
}: let
  inherit (self.deploy) nodes;
in {
  deploy_contract = assert (nodes.lavpc.fastConnection or false);
  assert !(nodes.tyrant ? fastConnection);
    pkgs.runCommand "deploy-contract" {} "touch $out";
}
