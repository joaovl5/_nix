{
  nx = {config, ...}: let
    cfg = config.my.nix;
    home_path = config.users.users.${cfg.username}.home;
  in {
    environment.variables."CODEX_HOME" = "${home_path}/.codex";
  };

  hm = {lib, ...}: {
    programs.codex = {
      enable = true;
      custom-instructions = lib.readFile ./extra_instruct.md;
      settings = {
        approval_policy = "on-request";
        sandbox_mode = "workspace-write";
        model_reasoning_effort = "medium";

        features = {
          shell_snapshot = true;
          exec_policy = true;
          remote_models = true;
        };

        tui = {
          alternate_screen = "never";
          notifications = true;
        };

        web_search = "cached";

        # model = "moonshotai/Kimi-K2.5";
        # model = "moonshotai/Kimi-K2.5";
        model_provider = "openai";
        model_providers = {
          deepinfra = {
            name = "DeepInfra";
            baseUrl = "https://api.deepinfra.com/v1/openai";
            envKey = "DEEPINFRA_KEY";
            wire_api = "chat";
          };
          openai = {
            name = "OpenAI";
            baseUrl = "https://api.openai.com/v1";
            envKey = "OPENAI_KEY";
            wire_api = "responses";
          };
          ollama = {
            name = "Ollama";
            baseURL = "http://localhost:11434/v1";
          };
        };
      };
    };
  };
}
