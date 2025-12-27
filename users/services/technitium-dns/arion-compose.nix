{...}: {
  project.name = "technitium-dns";
  services = {
    technitium.service = {
      image = "technitium/dns-server:latest";
      container_name = "technitium-dns";
      hostname = "dns";
      ports = [
        "5380:5380/tcp" # dns web console - http
        "53443:53443/tcp" # dns web console - https
        "53:53/tcp" # dns service
        "53:53/udp" # dns service
        # "853:853/udp" # dns-over-quic service
        # "853:853/tcp" # dns-over-tls service
        # "443:443/udp" # dns-over-https service (http/3)
        # "443:443/tcp" # dns-over-https service (http/1.1, http/2)
        # "80:80/tcp" # dns-over-http service (use with reverse proxy or certbot certificate renewal)
        # "8053:8053/tcp" # dns-over-http service (use with reverse proxy)
        # "67:67/udp" # dhcp service
      ];
      environment = {
        "DNS_SERVER_DOMAIN" = "dns";
      };
      volumes = [
        "technitium-cfg:/etc/dns"
      ];
    };
  };
  docker-compose.volumes = {
    "technitium-cfg" = {};
  };
}
