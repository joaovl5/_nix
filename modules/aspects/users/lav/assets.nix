_: {
  den.aspects.lav.homeManager = let
    assets_path = ../../../../_assets;
  in {
    hybrid-links.links.assets = {
      from = assets_path;
      to = "~/assets";
    };
  };
}
