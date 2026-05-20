let
  raw_inputs = import ./unflake.nix;

  normalize_source = name: source:
    if name == "self" || name == "withInputs" || name == "__functor" || name == "_unflake"
    then source
    else if builtins.isAttrs source && source ? rev && !(source ? shortRev)
    then
      source
      // {
        shortRev = builtins.substring 0 7 source.rev;
      }
    else source;

  normalize_inputs = builtins.mapAttrs normalize_source;
in
  (normalize_inputs raw_inputs)
  // {
    withInputs = outputs:
      raw_inputs.withInputs (inputs: outputs (normalize_inputs inputs));
  }
