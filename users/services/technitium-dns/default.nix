{
  pkgs,
  config,
  ...
}: let
  services_dir = "projects";
  service_name = "technitium-dns";
  arion_compose_source = ./arion-compose.nix;
  compose_cmd = ''
    ${pkgs.arion}/bin/arion \
      --pkgs "import <nixpkgs> { system = builtins.currentSystem; }"
  '';
in {
  systemd.user.services.${service_name} = {
    Service.ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
      #!/run/current-system/sw/bin/bash
      export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
      ${compose_cmd} -f "${arion_compose_source}" up
    '';
    Unit.After = ["docker.service" "docker.socket"];
    Unit.X-SwitchMethod = "stop-start";
    Install.WantedBy = ["default.target"];
  };
}
