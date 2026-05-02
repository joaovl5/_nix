let
  source_metadata = {
    niri-stable = {
      lastModified = 1756556321;
      lastModifiedDate = "20250830121841";
    };
    niri-unstable = {
      lastModified = 1777627080;
      lastModifiedDate = "20260501091800";
    };
    xwayland-satellite-stable = {
      lastModified = 1755491097;
      lastModifiedDate = "20250818042457";
    };
    xwayland-satellite-unstable = {
      lastModified = 1773622265;
      lastModifiedDate = "20260316005105";
    };
  };
  normalize_source = name: source:
    source
    // (
      if source ? revision
      then {
        rev = source.revision;
        shortRev = builtins.substring 0 7 source.revision;
      }
      else {}
    )
    // (source_metadata.${name} or {});
  sources = builtins.mapAttrs normalize_source (import ./npins);
  input_overrides = import ./input-overrides.nix;
in
  import sources.with-inputs sources input_overrides
