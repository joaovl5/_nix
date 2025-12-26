{lib, ...}: let
  _systemd_container_name = name: "podman-container-${name}";
  _systemd_project_name = name: "podman-project-${name}";
  _systemd_volume_name = name: "podman-volume-${name}";
  _systemd_network_name = name: "podman-network-${name}";
in {
  make_volume = {}: {
  };
  make_container = {
    project_name,
    network_name,
    name,
    image,
    container_opts ? {},
    systemd_opts ? {},
  }: {
    virtualisation.oci-containers.containers.${name} = lib.mkMerge [
      {
        inherit image;
        extraOptions = [
          "--network=${network_name}"
        ];
      }
      container_opts
    ];
    systemd.services.${_systemd_container_name name} = lib.mkMerge [
      {
        serviceConfig = {
          Restart = lib.mkDefault 90 "on-failure";
          RestartSec = lib.mkDefault 90 "5s";
        };
        startLimitBurst = 3;
        unitConfig = {
          StartLimitIntervalSec = lib.mkDefault 90 120;
        };
        after = [
          "podman-volume-myproject_books.service"
        ];
        requires = [
          "podman-volume-myproject_books.service"
        ];
        partOf = [
          "${_systemd_project_name project_name}.target"
        ];
        wantedBy = [
          "${_systemd_project_name project_name}.target"
        ];
      }
      systemd_opts
    ];
  };
}
