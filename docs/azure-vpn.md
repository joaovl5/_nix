# Azure VPN usage

This guide covers day-to-day usage of the Azure VPN on `lavpc`.

The VPN is configured to be manually toggled: the strongSwan service
can load the VPN configuration without automatically dialing the
tunnel on boot or rebuild.

## Activate the system configuration

After pulling/applying the repo configuration on `lavpc`, switch to
the NixOS generation that includes the Azure VPN module, for example:

```sh
sudo nixos-rebuild switch --flake ~/src/my/nix/main#lavpc
```

If you use another deployment command for `lavpc`, use that instead.
The important part is that the active generation includes the Azure
VPN configuration.

## Connect the VPN

Start or reload strongSwan, then initiate the Azure child tunnel:

```sh
sudo systemctl start strongswan-swanctl.service
sudo swanctl --load-all
sudo swanctl --initiate --child azure-vnet
```

If the tunnel is already loaded, the last command is usually enough:

```sh
sudo swanctl --initiate --child azure-vnet
```

## Disconnect the VPN

Terminate the Azure VPN IKE connection:

```sh
sudo swanctl --terminate --ike azure-p2s
```

If you only want to terminate the child SA, use:

```sh
sudo swanctl --terminate --child azure-vnet
```

To stop strongSwan entirely:

```sh
sudo systemctl stop strongswan-swanctl.service
```

## Check VPN status

List active strongSwan security associations:

```sh
sudo swanctl --list-sas
```

A connected tunnel should show an established `azure-p2s` IKE SA and
an `azure-vnet` child SA.

Check the service state:

```sh
systemctl status strongswan-swanctl.service
```

Check logs:

```sh
journalctl -u strongswan-swanctl.service -b --no-pager
```

## Check private resource access

Use the private hostname or address you expect to reach through Azure
VPN:

```sh
PRIVATE_HOST='<private-hostname-or-ip>'
PRIVATE_PORT='<private-port>'
```

Check name resolution if using a hostname:

```sh
getent hosts "$PRIVATE_HOST"
```

Check routing:

```sh
ip route get "$PRIVATE_HOST"
```

Check TCP reachability:

```sh
nc -vz "$PRIVATE_HOST" "$PRIVATE_PORT"
```

For PostgreSQL endpoints, a TCP success means the VPN/network path is
working. Database login still requires valid PostgreSQL credentials.

## Reload after secret/config changes

If the VPN secrets or generated swanctl configuration changed, restart
the service and reload strongSwan:

```sh
sudo systemctl restart strongswan-swanctl.service
sudo swanctl --load-all
```

Then reconnect:

```sh
sudo swanctl --initiate --child azure-vnet
```

## Troubleshooting

### `swanctl --initiate` says the child does not exist

Reload the configuration:

```sh
sudo swanctl --load-all
```

Then retry:

```sh
sudo swanctl --initiate --child azure-vnet
```

### The tunnel does not establish

Check the strongSwan logs:

```sh
journalctl -u strongswan-swanctl.service -b --no-pager
```

Common causes are missing secrets, expired/incorrect certificates, an
unreachable gateway, or proposal/identity mismatches.

### The tunnel is established but the private resource does not respond

Check:

```sh
sudo swanctl --list-sas
ip route get '<private-hostname-or-ip>'
nc -vz '<private-hostname-or-ip>' '<private-port>'
```

If the tunnel is up but routing or TCP fails, the issue is likely
route selection, Azure-side access rules, DNS, or the target service
itself.

## Disable Azure VPN declaratively

To disable the VPN from the machine configuration, set the Azure VPN
module off for the host and rebuild:

```nix
my.azure-vpn.enable = false;
```

For normal day-to-day use, prefer leaving the module enabled and using
the connect/disconnect commands above.
