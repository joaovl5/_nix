{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.nix;
  home_path = config.users.users.${cfg.username}.home;
in rec {
  data_dir = "${home_path}/${cfg.private_data_dirname}/units";

  write_ini_from_attrset = name: attrset:
    pkgs.writeText name (lib.generators.toINI {} attrset);

  write_yaml_from_attrset = name: attrset:
    pkgs.runCommand name {
      nativeBuildInputs = [pkgs.yj];
      json = builtins.toJSON attrset;
    } ''
      printf '%s' "$json" | yj -jy > "$out"
    '';

  make_docker_unit = let
    default_compose_cmd = "docker compose";
  in
    {
      service_name,
      service_description ? "[${service_name}] - systemd unit",
      compose_obj,
      compose_cmd ? default_compose_cmd,
    }: {
      systemd.user.services.${service_name} = let
        docker_yaml = write_yaml_from_attrset "docker_compose_${service_name}.yaml" compose_obj;
        environment = {
          DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
        };
      in {
        enable = true;
        inherit environment;
        path = with pkgs; [
          docker
          docker-compose
        ];
        serviceConfig = {
          Type = "simple";
          ExecStart = pkgs.writeShellScript "exec_start_${service_name}" ''
            exec ${compose_cmd} -f ${docker_yaml} up
          '';
        };
        description = service_description;
        after = ["docker.service" "docker.socket"];
        wantedBy = ["default.target"];
      };
    };
}
