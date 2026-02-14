{
  self,
  deploy-rs,
  ...
}: {
  checks =
    builtins.mapAttrs
    (_system: deployLib: deployLib.deployChecks self.deploy)
    deploy-rs.lib;
}
