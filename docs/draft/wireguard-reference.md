# WireGuard on NixOS - Technical Reference

## Key Generation

```bash
umask 077
wg genkey > privatekey
wg pubkey < privatekey > publickey
```

Each peer needs a unique keypair. Store private keys with correct permissions (not world-readable). Use `privateKeyFile` over inline `privateKey`.

With agenix:

```nix
age.secrets.wg-key = {
  file = "${inputs.self.outPath}/secrets/wg-key.age";
  mode = "640";
  owner = "systemd-network";  # for systemd.network
  group = "systemd-network";
};
```

Auto-generate option: `networking.wireguard.interfaces.[name].generatePrivateKeyFile`

## AllowedIPs

- `192.168.26.9/32` - single IPv4 peer
- `192.168.26.0/24` - subnet
- `fd31:bf08:57cb::9/128` - single IPv6 peer
- `0.0.0.0/0` + `::/0` - proxy all traffic
- Must be unique per peer (overlapping = only one peer receives traffic)
- Some modules auto-configure routes from AllowedIPs

## NixOS Configuration Methods

### 1. `networking.wireguard.interfaces`

Does NOT auto-configure routes. Manual `ip route add` or postSetup scripts needed.

**Peer:**

```nix
{
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.2/24" ];
    listenPort = 51820;
    privateKeyFile = "/path/to/key";
    peers = [{
      publicKey = "...";
      allowedIPs = [ "10.100.0.1/32" ];
      endpoint = "server-ip:51820";
      persistentKeepalive = 25;
    }];
  };
}
```

**Proxy server** (addition to peer config, omit endpoint):

```nix
{
  networking.nat = {
    enable = true;
    enableIPv6 = true;
    externalInterface = "eth0";
    internalInterfaces = [ "wg0" ];
  };
  networking.wireguard.interfaces.wg0 = {
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
      ${pkgs.iptables}/bin/ip6tables -A FORWARD -i wg0 -j ACCEPT
      ${pkgs.iptables}/bin/ip6tables -t nat -A POSTROUTING -s fd00::/64 -o eth0 -j MASQUERADE
    '';
    postShutdown = ''
      # Same commands with -D instead of -A
    '';
  };
}
```

**Proxy client:** Set `allowedIPs = [ "0.0.0.0/0" "::/0" ]` and specify endpoint.

### 2. `networking.wg-quick.interfaces`

Higher-level, uses `wg-quick` tool. Manages routes automatically.

**Peer:**

```nix
{
  networking.wg-quick.interfaces.wg0 = {
    address = [ "10.0.0.2/24" "fd00::2/64" ];
    dns = [ "10.0.0.1" ];
    privateKeyFile = "/path/to/key";
    peers = [{
      publicKey = "...";
      presharedKeyFile = "/path/to/psk";  # optional extra security
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
      endpoint = "server-ip:51820";
      persistentKeepalive = 25;
    }];
  };
}
```

**Proxy server** additions: Same NAT + iptables as above, using `postUp`/`preDown` instead of `postSetup`/`postShutdown`.

**Reuse existing config:** `networking.wg-quick.interfaces.wg0.configFile = "/path/to/wg0.conf";`

**Systemd unit:** `wg-quick-wg0.service` (start/stop via systemctl)

### 3. `systemd.network` (systemd-networkd)

Most powerful. Native route/policy rule management. Dual-stack friendly.

**Peer:**

```nix
{
  networking.useNetworkd = true;
  networking.firewall.allowedUDPPorts = [ 51820 ];
  systemd.network = {
    enable = true;
    netdevs."50-wg0" = {
      netdevConfig = { Kind = "wireguard"; Name = "wg0"; MTUBytes = "1300"; };
      wireguardConfig = {
        PrivateKeyFile = "/run/keys/wireguard-privkey";
        ListenPort = 51820;
        RouteTable = "main";  # auto-create routes from AllowedIPs
        FirewallMark = 42;    # mark wg packets for policy routing
      };
      wireguardPeers = [{
        PublicKey = "...";
        AllowedIPs = [ "10.100.0.1/32" "fd00::1/128" ];
        Endpoint = "server-ip:51820";
        # RouteTable can also be set per-peer (overrides wireguardConfig)
      }];
    };
    networks."50-wg0" = {
      matchConfig.Name = "wg0";
      address = [ "10.100.0.2/24" "fd00::2/128" ];
    };
  };
}
```

**Proxy server** additions:

```nix
{
  networking.nat = {
    enable = true; enableIPv6 = true;
    externalInterface = "ens6"; internalInterfaces = [ "wg0" ];
  };
  systemd.network.networks."50-wg0".networkConfig = {
    IPv4Forwarding = true;
    IPv6Forwarding = true;
    # Do NOT use IPMasquerade - causes problems with host IPv6
  };
}
```

**Proxy client** - route all traffic + DNS over wg0:

```nix
{
  networking.firewall.checkReversePath = "loose";  # rpfilter breaks wg

  systemd.network = {
    netdevs."50-wg0".wireguardPeers = [{
      AllowedIPs = [ "0.0.0.0/0" "::/0" ];
      Endpoint = "[2a01::1]:51820";  # must be IP, not domain (DNS routed over wg)
      FirewallMark = 42;
      RouteTable = 1000;  # separate routing table for wg
    }];

    networks."50-wg0" = {
      # DNS over wg (systemd-resolved)
      domains = [ "~." ];
      dns = [ "proxy-server-internal-ip" ];
      networkConfig.DNSDefaultRoute = true;

      # Route all non-wg traffic through wg
      routingPolicyRules = [
        {
          Family = "both";
          InvertRule = true;
          FirewallMark = 42;  # non-wg packets...
          Table = 1000;       # ...use wg routing table
          Priority = 10;
        }
        {
          To = "2a01::1/128";  # endpoint exemption
          Priority = 5;        # higher priority = checked first
        }
      ];
    };
  };
}
```

**Exempt specific addresses** (e.g., LAN):

```nix
{ To = "192.168.0.0/24"; Priority = 9; }
```

**Route for specific user only** (e.g., transmission):

```nix
routingPolicyRules = [
  { Table = 1000; User = "transmission"; Priority = 30001; Family = "both"; }
  { Table = "main"; User = "transmission"; SuppressPrefixLength = 0; Priority = 30000; Family = "both"; }
];
```

**Manual control:** `networkctl up/down wg0`

### 4. NetworkManager

Client-only. Import wg-quick config: `nmcli connection import type wireguard file wg0.conf`

## Traffic Relay (CGNAT Bypass)

### Architecture

Client -> Server A (relay, good connection) -> Server B (desired exit IP)

Server A has two WireGuard interfaces:

- `wg0`: client <-> server A
- `vpn-relay`: server A <-> server B

### Relay Config (Server A -> Server B)

Key: use **policy routing** to avoid breaking SSH access to Server A.

```ini
[Interface]
Address = 10.10.10.200/32
PrivateKey = ...
Table = 1234
PostUp = ip rule add dport 25-20480 table 1234;
PreDown = ip rule delete dport 25-20480 table 1234;

[Peer]
PublicKey = ...
AllowedIPs = 0.0.0.0/0
Endpoint = server-b-ip:51820
PersistentKeepalive = 25
```

Port range 25-20480 routes through relay; SSH (22) stays direct.

### Firewall on Server A (link client traffic to relay)

NAT rule forwards client subnet through relay interface:

```
-A POSTROUTING -s 10.10.10.0/24 -d 0.0.0.0/0 -o vpn-relay -j MASQUERADE
```

Plus FORWARD rules on relay interface:

```
iptables -A FORWARD -i vpn-relay -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -d 0.0.0.0/0 -o vpn-relay -j MASQUERADE
```

### Port Forwarding (VPS -> Home Server behind CGNAT)

On VPS, forward specific ports through WireGuard to home server:

```bash
# HTTP (port 80)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 192.168.4.2:80
iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 80 -d 192.168.4.2 -j SNAT --to-source 192.168.4.1
iptables -A FORWARD -i eth0 -o wg0 -p tcp --dport 80 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i wg0 -o eth0 -p tcp --sport 80 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH (remap VPS:2222 -> home:22)
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 2222 -j DNAT --to-destination 192.168.4.2:22
iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 22 -d 192.168.4.2 -j SNAT --to-source 192.168.4.1
```

VPS needs `net.ipv4.ip_forward = 1`.

## Automatic Failover (Advanced)

Architecture: 3 systemd services + Prometheus smokeping probers.

**Components:**

1. `wg-select` - picks initial server (from state file or random), runs before wg.service
2. `wg-failover` - queries Prometheus for packet loss per server, switches to lowest-loss alternative
3. `wg-health-check` - timer (1min), checks tunnel quality, triggers failover after 3 consecutive failures >15% loss

**Two probers:**

- External (on hypervisor): pings all VPN server endpoints directly - measures reachability of servers you're NOT connected to
- Internal (in VPN namespace): pings root DNS through active tunnel - measures actual tunnel quality

**Failover trigger:** wg.service `OnFailure = "wg-failover.service"` + health check timer.

Config symlink pattern: `/run/wg-active.conf` -> `/run/secrets/wireguard/$SERVER`

## DNS Options

**dnsmasq** (bind to wg interface):

```nix
{
  networking.firewall = { allowedTCPPorts = [ 53 ]; allowedUDPPorts = [ 53 ]; };
  services.dnsmasq = { enable = true; settings.interface = "wg0"; };
}
```

**kresd** (secure DNS for proxy client):

```nix
{
  services.kresd.enable = true;
  services.resolved.enable = false;
  environment.etc."resolv.conf" = { mode = "0644"; text = "nameserver ::1"; };
}
```

**systemd-resolved** (route DNS over wg):

```nix
systemd.network.networks."50-wg0" = {
  domains = [ "~." ];
  dns = [ "server-internal-ip" ];
  networkConfig.DNSDefaultRoute = true;
};
```

Warning: `Domains=~.` prevents DNS resolution of WireGuard endpoints. Use IP addresses for endpoints, not domains.

## rpfilter (Reverse Path Filtering)

NixOS firewall blocks wg traffic when routing all traffic through tunnel. Solutions (pick one):

1. `networking.firewall.checkReversePath = "loose";` (recommended)
2. `networking.firewall.checkReversePath = false;`
3. Manual iptables exemption:

```nix
networking.firewall = {
  logReversePathDrops = true;
  extraCommands = ''
    ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
    ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
  '';
  extraStopCommands = ''
    ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
    ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
  '';
};
```

## Troubleshooting

**persistentKeepalive not working with privateKeyFile:** PostUp sets private key after config, breaking auto-connect. Workaround:

```nix
postUp = [ "wg set wg0 peer ${publicKey} persistent-keepalive 25" ];
# Don't set persistentKeepalive in peers
```

**Some services fail but ping works:** MTU too large. Default is 1420 (1500 - 80 wg overhead). Lower it:

```nix
networking.wireguard.interfaces.wg0.mtu = 1000;  # tune upward from here
```

**wg-quick + NetworkManager issues:** Enable systemd-resolved:

```nix
networking.networkmanager.dns = "systemd-resolved";
services.resolved.enable = true;
```

**systemd-networkd cleans up custom ip rules:** Set in `/etc/systemd/networkd.conf`:

```
ManageForeignRoutes=No
ManageForeignRoutingPolicyRules=No
```

Or define rules in `.network` files (preferred on NixOS via `routingPolicyRules`).

## Testing

```bash
curl -4 zx2c4.com/ip          # check IPv4 exit
curl -6 zx2c4.com/ip          # check IPv6 exit
sudo wg show                   # tunnel status + handshake
journalctl -u systemd-networkd # networkd logs
ip route show table 1000       # inspect custom route table
ip route show table all
ip rule list
ip route get <destination>
```
