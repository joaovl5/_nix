{
  hm = _: let
    assets_path = ../../../_assets;
  in {
    hybrid-links.links.assets = {
      from = assets_path;
      to = "~/assets";
    };
  };
}
