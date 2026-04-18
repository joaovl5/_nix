{
  pkgs,
  lib,
  images,
  shared_assets_identity,
  ...
}:
pkgs.writeText "frag-image-catalog.json" (
  builtins.toJSON {
    images =
      lib.mapAttrs (key: spec: {
        inherit key shared_assets_identity;
        inherit (spec) image_ref;
        loader = spec.loader_name;
      })
      images;
  }
)
