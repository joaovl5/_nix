{
  pkgs,
  lib,
  ...
}: let
  svc_name = "pihole";
  svc_description = "Pi-hole service";
  group_gid = 998;
  user_uid = 1008;
in {
  users.groups.${svc_name} = {
    name = svc_name;
    gid = group_gid;
  };
  users.users.${svc_name} = {
    group = svc_name;
    uid = user_uid;
    description = svc_description;
    shell = pkgs.bash;
    extra_groups = ["podman"];
    linger = true; # required for autostarts
    isNormalUser = true;
  };
  nix.settings.allowed-users = [svc_name];
  home-manager.users.${svc_name} = {
    programs.bash.enable = true;
    services.podman.enable = true;
    services.podman.autoUpdate.enable = true;
    services.podman.networks.${svc_name} = {
      driver = "bridge";
      description = "[app network] - ${svc_description}";
    };
    systemd.user.services."pod-${svc_name}" = let
      required_pods = [];
      required_containers = [];
      required_networks = [];
      default_network = "pihole";
      wanted_by_containers = [];
      port_binds = [
        "0.0.0.0:80:80/tcp"
      ];
    in {
      Unit = {
        Description = "[pod service] - ${svc_name}";
        Requires =
          lib.map (x: "podman-${x}-network.service") required_networks
          ++ lib.map (x: "podman-${x}.service") required_containers
          ++ lib.map (x: "pod-${x}.service") required_pods;
        Wants = ["network-online.target"];
        After = ["network-online.target"];
      };
      Install = {
        WantedBy = lib.map (x: "podman-${x}.service") wanted_by_containers;
      };
      Service = {
        Type = "forking";
        ExecStartPre = [
          # required for autostart
          "${pkgs.coreutils}/bin/sleep 3s"
          # Port config see:
          # https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference
          # The image requires `--userns=host`
          ''
            -${pkgs.podman}/bin/podman pod create --replace \
              --network=${default_network} \
              --userns=host \
              --label=PODMAN_SYSTEMD_UNIT=pod-${svc_name}.service \
              ${lib.strings.concatStringsSep "\\" (lib.map (x: "-p ${x}") port_binds)} \
              ${svc_name} # pod name
          ''
        ];
        ExecStart = "${pkgs.podman}/bin/podman pod start ${svc_name}";
        ExecStop = "${pkgs.podman}/bin/podman pod stop ${svc_name}";
        RestartSec = "1s";
      };
    };
  };
}
