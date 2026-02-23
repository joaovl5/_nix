# Non-host specific settings go here for defining units
# They should not be enabled here, otherwise they'd be enabled for every host.
# These reference units declared at `../users/_units`
{
  my = {
    "unit.octodns" = {
    };

    "unit.pihole" = {
    };

    "unit.litellm" = {
      config = {
        model_list = [
          {
            model_name = "gpt-5-mini";
            litellm_params = {
              model = "gpt-5-mini-2025-08-07";
              api_base = "https://api.openai.com";
              api_key = "os.environ/OPENAI_KEY";
            };
          }
        ];
      };
    };

    "unit.nixarr" = {
    };

    "unit.soularr" = {
    };

    "unit.fxsync" = {
    };
  };
}
