{
  nixos_config,
  inputs,
  ...
}: let
  globals = import inputs.globals;
  fxsync_cfg = nixos_config.my."unit.fxsync";
  inherit (globals.dns) tld;
in {
  "browser.toolbars.bookmarks.visibility" = "never";
  "identity.sync.tokenserver.uri" = "https://${fxsync_cfg.endpoint.target}.${tld}/1.0/sync/1.5";
}
