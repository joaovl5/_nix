{
  hm = {
    config,
    lib,
    nixos_config,
    ...
  }: let
    inherit (lib) mkIf;

    cfg = nixos_config.my.storage.client;
    shared_root = cfg.mount_point;

    mk_link = name: relative_path: {
      from = config.lib.file.mkOutOfStoreSymlink "${shared_root}/${relative_path}";
      to = "~/${name}";
      hybrid = false;
      recursive = false;
      force = true;
    };
  in {
    config = mkIf cfg.enable {
      hybrid-links.links = {
        docs = mk_link "docs" "docs";
        dwnl = mk_link "dwnl" "dwnl";
        vids = mk_link "vids" "vids";
        pics = mk_link "pics" "pics";
        misc = mk_link "misc" "misc";
        sensitive = mk_link ".sensitive" "docs/core";
      };
    };
  };
}
