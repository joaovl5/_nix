{pkgs, ...}: {
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
    }: {
      systemd.user.services.${service_name} = {
        enable = true;
        path = [
          pkgs.arion
        ];
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
            export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
            PROJ_DIR="~/projects/${service_name}"
            mkdir -p "$PROJ_DIR"
            cd "$PROJ_DIR"
            ${compose_cmd} -f "${compose_file}" up
          '';
        };
        description = service_description;
        after = ["docker.service" "docker.socket"];
        wantedBy = ["default.target"];
      };
    };
}
