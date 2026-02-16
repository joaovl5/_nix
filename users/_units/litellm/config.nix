# gets `opts` then "compiles" YAML settings for litellm
opts: let
  cfg = opts.config;
in
  {
    inherit
      (cfg)
      model_list
      ;
  }
  // (
    if (cfg.litellm_settings != null)
    then {inherit (cfg) litellm_settings;}
    else {}
  )
  // (
    if (cfg.general_settings != null)
    then {inherit (cfg) general_settings;}
    else {}
  )
