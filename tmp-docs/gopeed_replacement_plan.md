# Gopeed replacement plan for qBittorrent

## Scope

Replace `qbittorrent` on `tyrant` with Gopeed as:

1. an ad-hoc torrent/magnet downloader behind the existing `torrent` vhost;
   and
2. the torrent consumer for the -arr stack through a blackhole/drop-folder
   workflow.

This is a plan only. No production service replacement is made here.

## Decisions from review loop

- Rollout: use a maintenance cutover. Stop/disable qBittorrent and put Gopeed
  directly on `torrent.trll.ing` / `12011`; no staging vhost.
- -arr policy: use Gopeed blackhole for all -arr torrents and accept reduced
  native progress/seed-goal visibility.
- Existing qBittorrent payloads: keep indefinitely at
  `/srv/torrents/qbittorrent-archive`; do not create a home-directory
  convenience symlink.
- Packaging/deployment: native Nix package only. Do not use Docker as a
  fallback.

## Current repo state

- `tyrant` enables both `unit.nixarr` and `unit.qbittorrent` in
  `globals/hosts.nix`.
- `users/_units/nixarr/default.nix` enables Jellyfin, Prowlarr, Lidarr,
  Radarr, Sonarr, and Bazarr. Transmission is currently disabled.
- `users/_units/qbittorrent/default.nix` exposes qBittorrent on port `12011`,
  vhost target `torrent`, with VueTorrent enabled and downloads symlinked into
  the repo-local unit data area.
- `my.units.data_dir` resolves to `${home}/private/units`; Gopeed may expose
  small convenience links there, but real download payloads should remain
  outside `/home/tyrant`.
- `tyrant` has a host-level `home_snapshot` backup for `/home/tyrant`. Large
  torrent payloads must therefore stay outside real directories under
  `/home/tyrant`, or be explicitly excluded.

## Source facts checked

- Gopeed supports HTTP, BitTorrent, Magnet, and ED2K downloads:
  <https://github.com/GopeedLab/gopeed>.
- Gopeed has a Web/headless mode for remote download service, defaulting to
  port `9999`, with bind address, port, username/password, API token, storage
  dir, white-listed download dirs, and initial download config:
  <https://gopeed.com/docs/install#web>.
- Gopeed exposes an HTTP API for creating/managing tasks:
  <https://gopeed.com/docs/dev-api>.
- Gopeed OpenAPI says `Request.url` supports `http(s)`, `magnet`, and local
  torrent files; `Options.path` controls per-task output path; global config
  has `downloadDir`, `whiteDownloadDirs`, `webhook`, `script`, and
  `autoTorrent`.
- Gopeed BitTorrent config has `listenPort`, trackers, `seedKeep`,
  `seedRatio`, and `seedTime` in source: `internal/protocol/bt/config.go`.
- Gopeed source has script hooks for `DOWNLOAD_DONE` and `DOWNLOAD_ERROR`;
  scripts receive `GOPEED_EVENT`, `GOPEED_TASK_ID`, `GOPEED_TASK_NAME`,
  `GOPEED_TASK_STATUS`, and `GOPEED_TASK_PATH`.
- Current nixpkgs has `pkgs.gopeed` as a desktop Flutter app, not a ready-made
  `gopeed-web` service binary. The official Docker image runs the Web binary.
- Radarr/Sonarr do not currently have a native Gopeed download client.
  Upstream requests are open:
  - <https://github.com/Radarr/Radarr/issues/10564>
  - <https://github.com/GopeedLab/gopeed/issues/810>
- Radarr/Sonarr do support `Torrent Blackhole`: they write `.torrent` files to
  a `TorrentFolder` and scan a `WatchFolder` for completed downloads. Source
  settings: `TorrentFolder`, `WatchFolder`, optional magnet-file saving, and
  read-only behavior.

## Key architecture decision

Use Gopeed Web + a small local blackhole adapter.

Reason: Gopeed can consume local torrent files via API, but I did not find
built-in watched-folder support. The watched-folder piece exists in the -arr
blackhole client, not in Gopeed. Therefore, the missing bridge is a local
watcher that submits dropped `.torrent` files to Gopeed.

## Proposed runtime layout

Use one Gopeed instance:

- system user/group: `gopeed`
- state: `/var/lib/gopeed`
- storage: `/var/lib/gopeed/storage`
- ad-hoc downloads: `/var/lib/gopeed/downloads`
- reverse proxy target: maintenance cutover keeps `torrent.trll.ing` and
  internal port `12011`; qBittorrent must be stopped/disabled before Gopeed
  binds that port.

Blackhole directories:

```text
/var/lib/gopeed/blackhole/radarr/incoming     # Radarr TorrentFolder
/var/lib/gopeed/blackhole/radarr/work         # Gopeed active/incomplete output
/var/lib/gopeed/blackhole/radarr/completed    # Radarr WatchFolder; completed-only
/var/lib/gopeed/blackhole/radarr/submitted
/var/lib/gopeed/blackhole/radarr/failed

/var/lib/gopeed/blackhole/sonarr/incoming
/var/lib/gopeed/blackhole/sonarr/work
/var/lib/gopeed/blackhole/sonarr/completed
/var/lib/gopeed/blackhole/sonarr/submitted
/var/lib/gopeed/blackhole/sonarr/failed

/var/lib/gopeed/blackhole/lidarr/incoming
/var/lib/gopeed/blackhole/lidarr/work
/var/lib/gopeed/blackhole/lidarr/completed
/var/lib/gopeed/blackhole/lidarr/submitted
/var/lib/gopeed/blackhole/lidarr/failed
```

Start with Radarr/Sonarr. Add Lidarr once the same flow is proven.

## Migrating existing qBittorrent payload

Current qBittorrent payload paths:

- service-internal downloads: `/var/lib/qBittorrent/qBittorrent/downloads`
- repo-local convenience link: `/home/tyrant/private/units/qbittorrent`

The data was previously seeding, but preserving seeding state is not a
requirement. The requirement is to keep the bytes somewhere available without
backing them up.

Recommended storage target:

```text
/srv/torrents/qbittorrent-archive
```

Migration approach:

1. Before disabling qBittorrent, stop it cleanly so files are not changing.
2. Move or copy the current payload from
   `/var/lib/qBittorrent/qBittorrent/downloads` into
   `/srv/torrents/qbittorrent-archive`.
3. Make the archive readable by the Gopeed service user and by the specific
   Radarr/Sonarr/Lidarr service users or shared media group confirmed on
   `tyrant`; do not make it Gopeed's default active download directory.
4. Do not create a `/home/tyrant/private/units/...` convenience symlink; keep
   the archive only under `/srv/torrents/qbittorrent-archive`.
5. Do not add this archive to `my."unit.gopeed".backup.items`.

Backup safety:

- `/srv/torrents/qbittorrent-archive` is outside the current `/home/tyrant`
  host snapshot and is not backed up unless explicitly added.
- If any real migrated data is placed under `/home/tyrant/private/units`, add
  explicit excludes to `globals/hosts.nix` under
  `my."unit.backup".host_items.home_snapshot.path.exclude` before moving data
  there.
- No home-directory symlink is planned. If one is added later, the backup
  should only record the symlink, not the target; still prefer the
  `/srv/torrents` location to keep the intent obvious.

## Proposed Nix changes

### 1. Add a `unit.gopeed`

Create `users/_units/gopeed/default.nix` following existing unit style:

- options:
  - `enable`
  - `endpoint`, default port `12011`, target `torrent`
  - no staging endpoint in the chosen rollout; qBittorrent and Gopeed exchange
    ownership of `12011` during maintenance cutover
  - `data_dir`, default `${u.data_dir}/gopeed`
  - `torrent.peer_port`, default can reuse `55055` only after confirming
    qBittorrent is disabled and no other service listens there
  - `blackhole.enable`, default `true`
  - per-app toggles for `radarr`, `sonarr`, `lidarr`
- config:
  - `my.vhosts.gopeed` or `my.vhosts.torrent` using endpoint target `torrent`
  - system user/group `gopeed`
  - `systemd.tmpfiles` for all state/download/blackhole dirs
  - first rollout should define no Gopeed backup item; if backing up metadata
    later, explicitly exclude active downloads, blackhole `work`/`completed`
    folders, and the qBittorrent archive
  - secret-backed Web password and API token via SOPS
  - Gopeed config generated into `/run/gopeed/config.json`
  - service PATH must include Gopeed script interpreters/tools used by hooks,
    at minimum `bash` and `coreutils` if using the planned `.sh` completion
    hook

### 2. Provide a headless Gopeed package

Preferred: package a native `gopeed-web` binary in `packages/gopeed-web`.

Implementation choices to evaluate:

- Build from source with `go build -tags nosqlite,web ./cmd/web`, ensuring
  `cmd/web/dist` is present from a Flutter web build.
- If the Flutter web build is too heavy, package the official
  `gopeed-web-$version-linux-amd64.zip` release artifact with `fetchzip` and
  pin hash/version.

Do not use the official Docker image as fallback; this rollout is native Nix
package only.

### 3. Disable qBittorrent

During the maintenance cutover:

- stop qBittorrent before Gopeed starts;
- set `my."unit.qbittorrent".enable = false` for `tyrant`;
- keep `nixarr.transmission.enable = false`;
- enable `unit.gopeed` for `tyrant` on port `12011`.

Do not delete the qBittorrent unit immediately; leave it available for
rollback until Gopeed has been stable for a few days.

## Gopeed service config

Example generated config shape:

```json
{
  "address": "127.0.0.1",
  "port": 12011,
  "username": "gopeed",
  "password": "<from sops>",
  "apiToken": "<from sops>",
  "storageDir": "/var/lib/gopeed/storage",
  "whiteDownloadDirs": [
    "/var/lib/gopeed/downloads",
    "/var/lib/gopeed/blackhole/radarr/work/*",
    "/var/lib/gopeed/blackhole/sonarr/work/*",
    "/var/lib/gopeed/blackhole/lidarr/work/*"
  ],
  "downloadConfig": {
    "downloadDir": "/var/lib/gopeed/downloads",
    "maxRunning": 5,
    "protocolConfig": {
      "bt": {
        "listenPort": 55055,
        "seedKeep": false,
        "seedRatio": 1.0,
        "seedTime": 86400
      }
    },
    "script": {
      "enable": true,
      "paths": ["/run/gopeed/scripts/complete-blackhole.sh"]
    }
  }
}
```

Notes:

- Keep Web auth enabled because this is exposed through Traefik.
- Keep API token separate from Web password.
- Confirm exact `protocolConfig.bt` schema against the packaged Gopeed version
  before deploying.
- Confirm whether Gopeed persists `downloadConfig` only on first boot. If yes,
  config changes may require API updates or resetting stored config.

## Blackhole adapter design

Add one watcher per app:

- `gopeed-blackhole-radarr.path`
- `gopeed-blackhole-sonarr.path`
- `gopeed-blackhole-lidarr.path`

Each `.path` watches the app `incoming` directory and starts a corresponding
oneshot service. The submission service:

1. waits briefly for dropped files to stop changing;
2. loops over new `*.torrent` files;
3. creates a unique per-task work directory, e.g.
   `/var/lib/gopeed/blackhole/radarr/work/<safe-release-name>-<short-hash>`;
4. submits each torrent to Gopeed with `opts.path` set to that unique work
   directory, not the -arr watch folder:

```json
{
  "req": {
    "url": "/var/lib/gopeed/blackhole/radarr/incoming/Release.Name.torrent",
    "labels": {
      "source": "radarr-blackhole"
    }
  },
  "opts": {
    "path": "/var/lib/gopeed/blackhole/radarr/work/Release.Name-a1b2c3d4"
  }
}
```

against `POST /api/v1/tasks` with `X-Api-Token`.

5. copies or moves successfully submitted torrents to `submitted/`;
6. moves failed submissions to `failed/` and exits non-zero for journal
   visibility.

Gopeed completion handling:

1. enable Gopeed's script hook and install
   `/run/gopeed/scripts/complete-blackhole.sh`;
2. the hook runs on `GOPEED_EVENT=DOWNLOAD_DONE` and receives
   `GOPEED_TASK_PATH`;
3. if `GOPEED_TASK_PATH` is under an app `work/<unique-id>` directory, move
   the completed file/folder into that app's `completed` directory with an
   atomic same-filesystem rename;
4. do not expose `work` as an -arr `WatchFolder`, because Radarr/Sonarr may
   otherwise see partial files.

Optional phase 2: support `.magnet` files by reading the magnet URI and
submitting it as `req.url`. Keep this disabled initially unless an indexer
cannot provide `.torrent` files.

## -arr configuration plan

Configure all enabled -arr apps to use Gopeed through Torrent Blackhole. Roll
it out one app at a time for validation:

- Download Client type: `Torrent Blackhole`
- Radarr:
  - Torrent Folder: `/var/lib/gopeed/blackhole/radarr/incoming`
  - Watch Folder: `/var/lib/gopeed/blackhole/radarr/completed`
- Sonarr:
  - Torrent Folder: `/var/lib/gopeed/blackhole/sonarr/incoming`
  - Watch Folder: `/var/lib/gopeed/blackhole/sonarr/completed`
- Lidarr:
  - Torrent Folder: `/var/lib/gopeed/blackhole/lidarr/incoming`
  - Watch Folder: `/var/lib/gopeed/blackhole/lidarr/completed`

Initial settings:

- Prefer `.torrent` files over magnets.
- Defer magnet-file support unless an indexer cannot provide `.torrent` files.
- Use Gopeed for all -arr torrents, including private trackers, with the
  accepted tradeoff that -arr cannot enforce per-indexer seed goals through a
  native client API.
- Treat cleanup conservatively at first. Verify whether `Read Only` must be
  disabled for imports/removal in your current -arr versions before enabling
  automatic deletion of completed files.

Important tradeoff: blackhole mode means -arr cannot track Gopeed progress
through a native API. It will only see completed files in the watch folder.
This is expected.

## Verification plan

### Local/repo checks

For the eventual Nix changes:

1. `nix fmt`
2. stage exact intended files only
3. `prek`
4. targeted build:
   `nix build .#nixosConfigurations.tyrant.config.system.build.toplevel --no-link`
5. evaluate
   `.#nixosConfigurations.tyrant.config.my."unit.backup".resolved_items` and
   confirm it does not include `/srv/torrents/qbittorrent-archive`,
   `/var/lib/gopeed/downloads`, or
   `/var/lib/gopeed/blackhole/*/{work,completed}`
6. confirm Gopeed metadata backup is intentionally absent for first rollout,
   or that any later metadata backup excludes payload directories
7. deploy with the existing `deploy` command only after checks pass

Avoid `nix flake check --all-systems` if it hits the known unrelated GitHub
fetch blocker; document it and keep the targeted `tyrant` build.

### Production smoke tests

After the maintenance cutover deploy:

1. `systemctl status gopeed.service`
2. local HTTP check against `http://127.0.0.1:12011/`
3. Traefik check: final `torrent.trll.ing` loads Gopeed login
4. API check with token: `GET /api/v1/tasks`
5. ad-hoc HTTP download test to `/var/lib/gopeed/downloads`
6. small torrent-file test through Gopeed UI/API
7. blackhole test:
   - drop a known `.torrent` into `radarr/incoming`
   - verify watcher moves or copies it to `submitted/`
   - verify Gopeed creates a task with output under `radarr/work`
   - verify `radarr/completed` remains empty while the task is incomplete
   - verify the Gopeed completion hook moves the final file/folder into
     `radarr/completed`
   - verify Radarr sees/imports the completed file
8. verify the qBittorrent archive already exists at
   `/srv/torrents/qbittorrent-archive`
9. verify the archive is outside backup scope and readable by the intended
   service users
10. repeat blackhole validation for Sonarr and Lidarr as each app is enabled

If smoke tests fail, roll back to qBittorrent using the preserved unit/config;
otherwise leave qBittorrent disabled.

## Risks and mitigations

- **No native Gopeed client in -arr:** use Torrent Blackhole + watcher. Accept
  reduced progress visibility.
- **No confirmed built-in Gopeed watched folder:** systemd.path submission
  watchers plus Gopeed completion script hooks supply the missing pieces.
- **Packaging uncertainty:** current nixpkgs package is desktop-oriented.
  Prefer a native `gopeed-web` package; use the official release artifact if
  building Flutter web is too expensive.
- **Private tracker ratio/HnR risk:** configure Gopeed seed ratio/time before
  using private trackers. Blackhole mode will not let -arr manage per-indexer
  seed goals via client API.
- **Cleanup semantics:** verify blackhole `Read Only` and completed download
  handling before allowing -arr to delete imported data.
- **Path/hardlink behavior:** keep Gopeed `work` and `completed` dirs, and
  media libraries when possible, on the same filesystem.
- **Backup bloat risk:** keep migrated qBittorrent payloads and active Gopeed
  downloads outside backed-up paths; verify backup resolved items before
  deploy.
- **Endpoint conflict risk:** qBittorrent and Gopeed cannot both own `12011`;
  chosen mitigation is a maintenance cutover.
- **Security:** do not expose Gopeed Web without auth; keep API token
  secret-backed.

## Recommended rollout

1. Package Gopeed Web as a native Nix package.
2. Prepare Gopeed unit, blackhole watcher, completion hook, secrets, and
   directories.
3. Enter maintenance cutover: stop qBittorrent and archive its payload under
   `/srv/torrents/qbittorrent-archive`.
4. Deploy `tyrant` with qBittorrent disabled and Gopeed enabled on
   `torrent.trll.ing` / `12011`.
5. Verify ad-hoc Web/API downloads.
6. Enable blackhole workflow for Radarr and verify import end-to-end.
7. Add Sonarr.
8. Add Lidarr if desired.
9. After a few stable days, decide whether to remove qBittorrent config
   entirely.
