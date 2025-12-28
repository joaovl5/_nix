{
  pkgs,
  config,
  ...
}: let
  cfg = config.my_nix;
in {
  make_docker_service = let
    default_compose_cmd = ''
      arion \
        --pkgs "import <nixpkgs> { system = builtins.currentSystem; }" \
    '';
  in
    {
      service_name,
      service_description ? "[${service_name}] - systemd unit",
      compose_file,
      compose_cmd ? default_compose_cmd,
    }: let
      project_dir = "${config.users.users.${cfg.username}.home}/projects/${service_name}";
    in {
      systemd.user.services.${service_name} = {
        enable = true;
        path = [
          pkgs.arion
        ];
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
            export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
            PROJ_DIR="${project_dir}"
            mkdir -p "$PROJ_DIR"
            cd "$PROJ_DIR"
            exec ${compose_cmd} -f "${compose_file}" up
          '';
          WorkingDirectory = project_dir;
        };
        description = service_description;
        after = ["docker.service" "docker.socket"];
        wantedBy = ["default.target"];
      };
    };
}
