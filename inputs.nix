let
  normalize_source = _name: source:
    source
    // (
      if source ? revision
      then {
        rev = source.revision;
        shortRev = builtins.substring 0 7 source.revision;
      }
      else {}
    );
  sources = builtins.mapAttrs normalize_source (import ./npins);
  input_overrides = import ./input-overrides.nix;
in
  import sources.with-inputs sources input_overrides
