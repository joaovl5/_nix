{
  hm = {
    pkgs,
    config,
    ...
  }: {
    programs.codex = {
      enable = true;
      settings = {
        model = "gpt-5.2";
        model_provider = "openai";
        approval_policy = "on-request";
        sandbox_mode = "workspace-write";
        model_reasoning_effort = "high";

        features.shell_snapshot = true;
        features.web_search_request = false;

        providers.openai = {
          name = "OpenAI";
          base_url = "https://api.openai.com/v1";
          env_key = "OPENAI_KEY";
          wire_api = "chat";
          query_params = {};
        };
      };
    };
  };
}
