{
  pkgs,
  lib,
  images,
  ...
}:
pkgs.writeText "frag-image-catalog.json" (
  builtins.toJSON {
    images =
      lib.mapAttrs (_key: spec: {
        inherit (spec) image_ref;
        loader = spec.loader_name;
      })
      images;
  }
)
