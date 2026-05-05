{
  config,
  mylib,
  pkgs,
  ...
}: let
  o = (mylib.use config).options;
  rootless_cdi_script = pkgs.writeShellScript "nvidia-rootless-cdi" ''
    set -euo pipefail

    src="/var/run/cdi/nvidia-container-toolkit.json"
    if [ ! -r "$src" ]; then
      echo "nvidia-rootless-cdi: source CDI spec is not readable: $src" >&2
      exit 0
    fi

    : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
    dst_dir="''${XDG_RUNTIME_DIR}/cdi"
    dst="$dst_dir/nvidia-container-toolkit.json"

    ${pkgs.coreutils}/bin/mkdir -p "$dst_dir"
    tmp="$(${pkgs.coreutils}/bin/mktemp "$dst.XXXXXX")"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

    ${pkgs.jq}/bin/jq '(
      .. | objects | .mounts? | arrays | .[] | objects
      | select((.hostPath | type) == "string" and (.hostPath | startswith("/etc/egl/egl_external_platform.d/")))
      | .hostPath
    ) |= sub("^/etc/egl/egl_external_platform\\.d"; "/run/opengl-driver/share/egl/egl_external_platform.d")' "$src" > "$tmp"

    ${pkgs.coreutils}/bin/mv "$tmp" "$dst"
    trap - EXIT
  '';
in
  o.module "nvidia" (with o; {
    enable = toggle "Enable nvidia settings" true;
    cuda_cap = opt "Cuda capability setting" t.str "8.6";
  }) {} (
    opts:
      o.when opts.enable {
        hardware = {
          nvidia-container-toolkit.enable = true;
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            modesetting.enable = true;
            powerManagement.enable = true;
            powerManagement.finegrained = false;
            open = true;
            nvidiaSettings = true;
          };
        };
        nixpkgs.config.cudaSupport = true;
        nixpkgs.config.cudaCapabilities = [opts.cuda_cap];
        services.xserver.videoDrivers = ["nvidia"];
        environment.systemPackages = [pkgs.libnvidia-container];
        systemd.user.services.nvidia-rootless-cdi = {
          description = "Prepare NVIDIA CDI spec for rootless Docker";
          wantedBy = ["default.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = rootless_cdi_script;
          };
        };
        systemd.user.paths.nvidia-rootless-cdi = {
          wantedBy = ["default.target"];
          pathConfig = {
            PathChanged = "/var/run/cdi/nvidia-container-toolkit.json";
            Unit = "nvidia-rootless-cdi.service";
          };
        };
        virtualisation.docker.rootless = {
          daemon.settings = {
            dns = [
              "1.1.1.1"
              "1.0.0.1"
            ];
            features.cdi = true;
          };
          extraPackages = [pkgs.libnvidia-container];
        };
      }
  )
