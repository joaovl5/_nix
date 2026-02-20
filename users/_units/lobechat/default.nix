##
## WIP
##
{
  mylib,
  config,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  inherit (o) t;
  inherit (lib) mkOption;

  LiteLLMParams = t.submodule (_: {
    options = {
      model = o.optional "LiteLLM model identifier" t.str {};
      api_base = o.optional "LiteLLM API base URL" t.str {};
      api_key = o.optional "LiteLLM API key" t.str {};
      rpm = o.optional "Requests per minute limit" t.int {};
      aws_region_name = o.optional "AWS region name" t.str {};
    };
  });

  ModelInfo = t.submodule (_: {
    options = {
      version = o.optional "Model info version" t.int {};
    };
  });

  Model = t.submodule (_: {
    options = {
      model_name = mkOption {
        description = "Received model name";
        type = t.str;
      };
      litellm_params = mkOption {
        description = "LiteLLM params for this model";
        type = LiteLLMParams;
        default = {};
      };
      model_info = o.optional "Model info" ModelInfo {default = {};};
    };
  });

  LitellmSettings = t.submodule (_: {
    options = {
      drop_params = o.optional "Drop unsupported params" t.bool {};
      success_callback = o.optional "Success callback backends" (t.listOf t.str) {default = [];};
    };
  });

  GeneralSettings = t.submodule (_: {
    options = {
      master_key = o.optional "Master key for auth" t.str {};
      alerting = o.optional "Alerting backends" (t.listOf t.str) {default = [];};
    };
  });
in
  #
  # Requisites:
  # - declaratively setup pi-hole secrets
  # - use octodns for managing zones
  # - use nixos-dns for zones
  # - manage state in centralized form
  o.module "unit.litellm" (with o; {
    enable = toggle "Enable Pihole" false;
    web = {
      host = opt "Interface to bind to" t.str "0.0.0.0";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
      host_domain = opt "Host Domain (used for DNS)" t.str "litellm.lan";
      port = opt "Web UI ports" t.int 2222;
      num_workers = opt "Worker count for web server" t.int 4;
    };
    config = {
      model_list = optional "LiteLLM model list" (t.listOf Model) {default = [];};
      litellm_settings = optional "LiteLLM module settings" LitellmSettings {default = null;};
      general_settings = optional "LiteLLM general settings" GeneralSettings {default = null;};
    };
  }) {} (opts: (o.when opts.enable (let
    user = "litellm";
    group = "litellm";
    litellm_config = import ./config.nix opts;
    litellm_config_yaml = u.write_yaml_from_attrset "litellm_config.yaml" litellm_config;
  in {
    sops.secrets = {
      "openai_key_litellm" = s.mk_secret "${s.dir}/api_keys.yaml" "openai" {
        owner = user;
        inherit group;
      };
    };

    users.users.${user} = {
      inherit group;
      isSystemUser = true;
    };
    users.groups.${group} = {};

    systemd.services.litellm = {
      description = "LiteLLM Proxy";
      wantedBy = ["default.target"];
      path = with pkgs; [
        litellm
      ];
      serviceConfig = {
        Type = "simple";
        User = user;
        Group = group;
        ExecStart = pkgs.writeShellScript "exec_litellm" ''
          export OPENAI_KEY=$(cat ${s.secret_path "openai_key_litellm"})

          litellm \
            --host ${opts.web.host} \
            --port ${toString opts.web.port} \
            --num_workers ${toString opts.web.num_workers} \
            --config ${litellm_config_yaml}

        '';
      };
    };
  })))
