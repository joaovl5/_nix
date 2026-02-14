{
  pkgs,
  config,
  ...
}: let
  cfg = config.my_nix;
  home_path = config.users.users.${cfg.username}.home;
in {
  data_dir = "${home_path}/${cfg.private_data_dirname}/services";

  make_docker_service = let
    default_compose_cmd = "docker compose";
  in
    {
      service_name,
      service_description ? "[${service_name}] - systemd unit",
      compose_obj,
      compose_cmd ? default_compose_cmd,
    }: let
      project_dir = "${config.users.users.${cfg.username}.home}/projects/${service_name}";
      compose_json = pkgs.writeTextFile {
        name = "compose_tmp_${service_name}.json";
        text = builtins.toJSON compose_obj;
      };
    in {
      systemd.user.services.${service_name} = {
        enable = true;
        path = with pkgs; [
          docker
          docker-compose
          yj
        ];
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
            export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
            PROJ_DIR="${project_dir}"
            COMPOSE_YML="$PROJ_DIR/compose.yml"
            mkdir -p "$PROJ_DIR"
            # convert to yaml
            yj -jy < "${compose_json}" > "$COMPOSE_YML"
            cd "$PROJ_DIR"
            exec ${compose_cmd} up
          '';
        };
        description = service_description;
        after = ["docker.service" "docker.socket"];
        wantedBy = ["default.target"];
      };
    };
}
