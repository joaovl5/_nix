{http_port}: {
  services = {
    openwebui = {
      image = "ghcr.io/open-webui/open-webui:main";
      container_name = "openwebui";
      ports = [
        "${http_port}:8080/tcp"
      ];
      environment = {
        "DNS_SERVER_DOMAIN" = "dns";
      };
      volumes = [
        "openwebui:/app/backend/data"
      ];
    };
    pipelines = {
      image = "ghcr.io/open-webui/pipelines:main";
      container_name = "openwebui_pipelines";
      volumes = [
        "pipelines:/app/pipelines"
      ];
    };
  };
  volumes = {
    "openwebui" = {};
  };
}
