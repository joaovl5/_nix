{pkgs, ...}: {
  make_docker_service = let
    default_compose_cmd = ''
      ${pkgs.arion}/bin/arion \
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
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
            #!/run/current-system/sw/bin/bash
            export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
            ${compose_cmd} -f "${compose_file}" up
          '';
        };
        description = service_description;
        after = ["docker.service" "docker.socket"];
        wantedBy = ["default.target"];
      };
    };
}
