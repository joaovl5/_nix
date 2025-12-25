{
  pkgs,
  config,
  ...
}: let
  services_dir = "projects";
  service_name = "pi-hole";
  compose_source = ./compose.yml;
  compose_target = "${services_dir}/${service_name}/compose.yml";
  compose_cmd = "${pkgs.podman-compose}/bin/podman-compose --podman-path ${pkgs.podman}/bin/podman";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in {
  home.file.${compose_target} = {
    force = true;
    source = mkSymlink compose_source;
  };

  systemd.user.services.${service_name} = {
    Service.ExecStart = pkgs.writeShellScript "exec_${service_name}" ''
      #!/run/current-system/sw/bin/bash
      ${compose_cmd} -f "$HOME/${compose_target}" up
    '';
    Unit.After = ["podman.service" "podman.socket"];
    Unit.X-SwitchMethod = "stop-start";
    Install.WantedBy = ["default.target"];
  };
}
