let
  sources = import ./npins;
  input_overrides = import ./input-overrides.nix;
in
  import sources.with-inputs sources input_overrides
