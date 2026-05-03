# Storage sync review

Date: 2026-04-07

Scope reviewed (read-only):

- `_scripts/storage/storage-graveyard-prune.py`
- `systems/_modules/storage/client.nix`
- `systems/_modules/storage/server.nix`
- `users/_modules/storage/default.nix`
- `users/_modules/storage/src_ignore_patterns.nix`
- `users/_modules/syncthing/default.nix`
- `users/_units/syncthing/default.nix`
- supporting wiring: `systems/astral/default.nix`, `systems/tyrant/default.nix`, `globals/hosts.nix`, `home/_modules/hybrid-links/default.nix`, `users/_modules/fish/setup.nix`, `users/_modules/cli/eza.nix`

Method:

- read-only repo inspection
- parallel reviewer subagents for independent scopes
- selective validation against external docs where semantics were not provable from repo code alone

User-reported runtime symptom incorporated into this review:

- `ls ~` takes about 1 minute
- top-level share links appear broken (`docs@`, `dwnl@`, `misc@`, `pics@`, `vids@`)
- `ls ~/.shared` returns `No such device (os error 19)`
- Syncthing appears healthy; NFS appears broken

## Executive summary

High confidence: the current `ls ~` hang is explained by a new interaction between three changes:

1. the storage client mounts NFS on `~/.shared` as an automount (`systems/_modules/storage/client.nix:29-38`),
2. the user storage module exposes `~/docs`, `~/dwnl`, `~/vids`, `~/pics`, `~/misc` (and hidden `~/.sensitive`) as symlinks into that NFS tree (`users/_modules/storage/default.nix:13-29`), and
3. `ls` on this machine resolves to `eza`, and the configured default flags include `-X` / `--dereference`, which makes the listing dereference symlink targets instead of only showing link metadata (`users/_modules/cli/eza.nix:8-15`; local `eza --help` confirms `-X, --dereference`).

That means a plain home-directory listing now touches NFS-backed targets and can block behind automount/mount failure. This matches the observed minute-long `ls ~` and the broken share entries.

There is also a likely server/client NFSv4 contract issue: the client forces `nfsvers=4.2` (`systems/_modules/storage/client.nix:32-38`), while the server export is emitted as raw `/srv/shared ...` lines without any `fsid=0` pseudo-root (`systems/_modules/storage/server.nix:70-72`). External NFSv4 documentation indicates a pseudo-root export is required for the NFSv4 namespace. This is a strong candidate for the reported `ENODEV` on `~/.shared`.

Syncthing is configured on a separate tree (`/srv/syncthing/src` on the server, `~/src` on the client), so “Syncthing works while NFS fails” is consistent with the current code.

## Primary diagnosis: NFS/home-listing regression

### 1) P1 — Top-level home symlinks now expose an unhealthy NFS automount to ordinary `ls ~`

Evidence:

- Client NFS mountpoint: `~/.shared` via `fileSystems.${opts.client.mount_point}` with `x-systemd.automount` in `systems/_modules/storage/client.nix:29-38`.
- `astral` enables that client module: `systems/astral/default.nix:28`.
- Home-visible links are created directly into that mount:
  - `docs`, `dwnl`, `vids`, `pics`, `misc`, `.sensitive`
  - `users/_modules/storage/default.nix:13-29`
- These are out-of-store symlinks via `mkOutOfStoreSymlink`, not copies/wrappers: `users/_modules/storage/default.nix:14`, `home/_modules/hybrid-links/default.nix:103-165`.

Impact:

- A routine home listing now touches remote-share-backed paths.
- When the automount is unhealthy, those top-level entries make `ls ~` user-visible and slow instead of confining the failure to `~/.shared`.

Confidence: high

### 2) P1 — `ls`/`eza` is configured to dereference symlink targets, which amplifies the NFS failure into a minute-long hang

Evidence:

- Fish integration for eza is enabled: `users/_modules/fish/setup.nix:19-29`.
- eza defaults include `-X`: `users/_modules/cli/eza.nix:8-15`.
- Local `eza --help` on this machine reports: `-X, --dereference          dereference symbolic links when displaying information`.
- The user’s `ls ~` output is clearly eza-formatted, so this path is active in practice.

Impact:

- `ls ~` does not merely show link metadata; it dereferences `~/docs`, `~/dwnl`, etc. and therefore trips the NFS automount / mount failure path.
- This directly explains why ordinary home listing became slow only after the new storage-link wiring.

Confidence: high

### 3) P1 — Likely NFSv4 export contract bug: client forces `nfsvers=4.2`, server export lacks an NFSv4 pseudo-root (`fsid=0`)

Evidence:

- Client mount options hardcode `nfsvers=4.2`: `systems/_modules/storage/client.nix:32-38`.
- Server export string is raw `/srv/shared ${client}(rw,sync,no_subtree_check,root_squash)` with no `fsid=0`: `systems/_modules/storage/server.nix:47,70-72`.
- Server host `tyrant` enables this module: `systems/tyrant/default.nix:8-13`.

Why this matters:

- External NFSv4 references describe a required pseudo-root export (`fsid=0`) for the NFSv4 namespace. With the current config, the client is explicitly requesting NFSv4.2 but the server-side exports do not declare such a root.
- That is a strong match for the observed `ls ~/.shared -> No such device (os error 19)`.

Confidence: medium-high

Notes:

- This conclusion depends on NFSv4 protocol semantics, not just repo text.
- External references used for validation are listed below.

### 4) P2 — The client mount options do not bound the failure path once NFS is unhealthy

Evidence:

- Client options are only:
  - `noauto`
  - `nofail`
  - `_netdev`
  - `nfsvers=4.2`
  - `x-systemd.automount`
  - `x-systemd.idle-timeout=...`
- See `systems/_modules/storage/client.nix:32-38`.

Impact:

- Nothing here limits lookup/mount delay once the automount is triggered and the server/export path is bad.
- Even if the root cause is the NFSv4 export mismatch above, this configuration makes the failure highly user-visible and slow.

Confidence: medium

### 5) Syncthing is probably not part of the current outage path

Evidence:

- Server-side Syncthing uses `/srv/syncthing/src`: `systems/_modules/storage/server.nix:21,68`; `users/_units/syncthing/default.nix:14-18,70-75`.
- Client-side Syncthing folder is `~/src`: `users/_modules/syncthing/default.nix:19-21,50-56`.
- NFS shared storage uses `/srv/shared` on the server and `~/.shared` on the client: `systems/_modules/storage/server.nix:17`; `systems/_modules/storage/client.nix:15-18`.

Impact:

- The user report “Syncthing looks fine but NFS is broken” matches the current separation of responsibilities in code.

Confidence: high

## Additional audit findings from the broader storage/sync review

### 6) P1 — Graveyard prune script can delete outside the graveyard root

Files:

- `_scripts/storage/storage-graveyard-prune.py:84-95`

Evidence:

- The script resolves and validates `buried_path.parent`, then reconstructs the final path as `buried_parent_resolved / buried_path.name`.
- A malformed `.record` entry whose parent resolves inside the graveyard but whose final joined path escapes (for example via `..`) can bypass the intended boundary check.

Impact:

- A bad `.record` line can cause deletion outside the configured graveyard.

Confidence: high

### 7) P2 — Graveyard prune drops `.record` entries even when recursive deletion fails

Files:

- `_scripts/storage/storage-graveyard-prune.py:56-62,94-99`

Evidence:

- Directory deletion uses `shutil.rmtree(entry_path, ignore_errors=True)`.
- The corresponding `.record` line is still removed afterwards because the line is not kept once the item is considered expired.

Impact:

- Partial deletion failures can leave residue on disk while removing the tombstone entry that would have allowed future retries.

Confidence: high

### 8) P3 — Negative graveyard retention values are accepted by Nix and rejected only at runtime

Files:

- `systems/_modules/storage/server.nix:25-30,100`
- `_scripts/storage/storage-graveyard-prune.py:105-107`

Evidence:

- `graveyard_retention_days` is typed as a plain integer in Nix.
- The Python script rejects negative values only when the timer job runs.

Impact:

- Bad config can evaluate/deploy cleanly and then fail only at runtime.

Confidence: high

### 9) P2 — Syncthing ignore patterns use trailing slashes, which ignore contents but not the directory entry itself

Files:

- `users/_modules/storage/src_ignore_patterns.nix:5-20`
- `users/_modules/syncthing/default.nix:50-56`

Evidence:

- Patterns include entries like `__pycache__/`, `.venv/`, `node_modules/`, `dist/`, `build/`, etc.
- Syncthing consumes this list directly as `ignorePatterns`.
- Syncthing docs state that a pattern ending with `/` matches the contents of the directory, not the directory itself.

Impact:

- These directories can still appear as empty placeholders on peers even though their contents are excluded.

Confidence: high

### 10) P1 — `~/src` Syncthing sync does not exclude `.git/`

Files:

- `users/_modules/storage/src_ignore_patterns.nix:1-21`
- `users/_modules/syncthing/default.nix:20-21,50-56`

Evidence:

- The synced client folder is `~/src`.
- The ignore list excludes caches/build outputs, but no `.git/` pattern is present.

Impact:

- Syncthing can replicate Git internals (`index.lock`, refs, rebase state, hooks, etc.) between machines.
- That is risky for active repositories and can cause stale lock files or machine-local repo state to bleed across hosts.

Confidence: high

## Lower-confidence / environment-dependent risks

These are plausible but not proven from repo state alone:

- Hostname-based NFS wiring uses `tyrant` on the client (`systems/_modules/storage/client.nix:17`) and `lavpc` in the server allowlist (`systems/_modules/storage/server.nix:23`). If local name resolution / Avahi is inconsistent, that could worsen or mask the mount issue.
- The exact minute-long delay length is kernel/runtime dependent. Repo code explains why `ls ~` now touches NFS, but not the exact timeout length.

## Suggested manual runtime checks (not executed in this review)

These are read-only checks you can run to confirm the current failure path:

1. `systemctl status home-lav-.shared.automount`
2. `systemctl status home-lav-.shared.mount`
3. `journalctl -b -u home-lav-.shared.automount -u home-lav-.shared.mount`
4. `findmnt /home/lav/.shared`
5. `showmount -e tyrant` (or direct export inspection on the server)
6. `nfsstat -m`
7. Compare:
   - `command ls -ld ~/{docs,dwnl,vids,pics,misc}`
   - `eza --long ~`
   - `eza --no-symlinks --long ~`

## External references used for semantic validation

- Syncthing ignore rules:
  - https://docs.syncthing.net/users/ignoring.html
- eza man page / option semantics:
  - https://manpages.debian.org/testing/eza/eza.1.en.html
  - local `eza --help` on this machine
- NFSv4 pseudo-root / `fsid=0` references:
  - https://www.rfc-editor.org/rfc/pdfrfc/rfc7530.txt.pdf
  - https://docs.redhat.com/es/documentation/red_hat_enterprise_linux/5/html/deployment_guide/s1-nfs-server-config-exports
  - https://www.ibm.com/support/pages/linux%C2%AE-and-aix%C2%AE-nfs-server-v4-configuration-tips

## Bottom line

The immediate production issue is most likely the NFS client/export wiring, not Syncthing:

- the new config made ordinary home listings dereference into an automounted NFS share,
- the share itself is currently failing (`ENODEV`), and
- the current NFSv4 client/server contract is very likely incomplete.

Separately, the storage review also surfaced a real prune-script safety bug and two Syncthing ignore/scope problems that should be reviewed even if they are not causing the current `ls ~` outage.
