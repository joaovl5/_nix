{
  pkgs,
  config,
  ...
}: let
  services_dir = "projects";
  service_name = "pi-hole";
  compose_source = ./compose.yml;
  compose_target = "${services_dir}/${service_name}/compose.yml";
  compose_cmd = "${pkgs.docker-compose}/bin/docker-compose --docker-path ${pkgs.docker}/bin/podman";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in {
  home.file.${compose_target} = {
    force = true;
    source = mkSymlink compose_source;
  };

  systemd.user.services.${service_name} = {
    Service.ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
      #!/run/current-system/sw/bin/bash
      ${compose_cmd} -f "$HOME/${compose_target}" up
    '';
    # Service.ExecStop = pkgs.writeShellScript "exec_stop_${service_name}" ''
    #   #!/run/current-system/sw/bin/bash
    #   ${compose_cmd} -f "$HOME/${compose_target}" down
    # '';
    Unit.After = ["docker.service" "docker.socket"];
    Unit.X-SwitchMethod = "stop-start";
    Install.WantedBy = ["default.target"];
  };
}
