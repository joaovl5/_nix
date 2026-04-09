# Storage Fix Implementation Plan

> For implementation in this session: use subagents for review and execution where scopes are independent.

**Goal:** Restore the broken NFS shared mount, make Syncthing `src` ignore rules reliably take effect on both peers, and keep `.git` syncing intentionally enabled.

**Architecture:** Fix the NFS outage at the storage contract layer by aligning the server export and client mount for explicit NFSv4 usage. Fix Syncthing ignore behavior by keeping `users/_modules/storage/src_ignore_patterns.nix` as the single policy source while (a) materializing a real local `.stignore` on the client `~/src`, where Home Manager does not manage folder ignores via Syncthing’s ignore API, and (b) feeding the same ignore list into the server’s NixOS Syncthing module, which does update folder ignores through Syncthing itself.
**Tech Stack:** NixOS modules, Home Manager modules, systemd, Syncthing, NFSv4.

---

## Scope and non-goals

### In scope

- Repair the NFS mount outage affecting `~/.shared`.
- Ensure Syncthing ignore rules for `src` are actually present and active on both peers.
- Preserve intentional syncing of `.git` contents in `~/src`.
- Normalize ignore patterns so Syncthing ignores full generated/cache directories, not just their contents.

### Out of scope

- Do not change the `~/docs`, `~/dwnl`, `~/pics`, `~/vids`, `~/misc` link layout unless the NFS contract fix proves insufficient.
- Do not remove `.git` from Syncthing ignore policy.
- Do not change unrelated graveyard-prune issues in this task.
- Do not change global `ls`/`eza` behavior in this task; treat that as optional future hardening if desired.

---

## Files expected to change

### NFS repair

- Modify: `systems/_modules/storage/server.nix`
- Modify: `systems/_modules/storage/client.nix`

### Syncthing ignore repair

- Modify: `users/_modules/storage/src_ignore_patterns.nix`
- Modify: `users/_modules/syncthing/default.nix`
- Modify: `users/_units/syncthing/default.nix`

### Verification/reporting

- No documentation update required unless implementation meaningfully diverges from the current audit.

---

## Chunk 1: Repair NFSv4 client/server contract

### Task 1: Export the shared tree as the NFSv4 pseudo-root

**Files:**

- Modify: `systems/_modules/storage/server.nix`

- [ ] Update the NFS export options so `/srv/shared` is exported as the NFSv4 pseudo-root.
- [ ] Keep existing access semantics (`rw`, `sync`, `no_subtree_check`, `root_squash`) intact.
- [ ] Do not introduce `crossmnt` unless repo evidence shows subordinate mounted filesystems under `/srv/shared`.
- [ ] Keep `allowed_clients` behavior unchanged.

**Expected code shape:**

- The export string for `cfg.shared_root` includes `fsid=0` (or equivalent NFSv4 root marker).

### Task 2: Align the client mount source with the NFSv4 pseudo-root

**Files:**

- Modify: `systems/_modules/storage/client.nix`

- [ ] Change the default remote path from `/srv/shared` to `/` so the client mounts the pseudo-root instead of the server filesystem path.
- [ ] Update the option description to reflect that the configured path is the client-visible NFS path, not necessarily the server’s raw filesystem path.
- [ ] Keep the local mountpoint at `~/.shared`.
- [ ] Keep `nfsvers=4.2` explicit.

**Expected code shape:**

- `export_path` defaults to `/`.
- The module description no longer implies this must literally equal the server filesystem path.

### Task 3: Verify the NFS config still evaluates cleanly

**Files:**

- No additional file changes.

- [ ] Run repo formatting and evaluation checks later in the verification chunk.
- [ ] After deployment, manual runtime validation should confirm the client mounts `tyrant:/` successfully and `ls ~/.shared` works.

---

## Chunk 2: Make Syncthing ignore rules materialize locally

### Task 4: Keep `.git` intentional and normalize ignore semantics

**Files:**

- Modify: `users/_modules/storage/src_ignore_patterns.nix`

- [ ] Keep `.git` absent from the ignore list.
- [ ] Add or refine a comment stating that `.git` syncing is intentional for LAN WIP sharing.
- [ ] Remove trailing `/` from directory patterns where the intent is to ignore the directory itself and all contents (`__pycache__`, `.venv`, `venv`, `node_modules`, `dist`, `build`, `coverage`, `tmp`, `.next`, `out`, `target`, etc.).
- [ ] Leave file patterns like `.DS_Store` and `*.py[oc]` as file patterns.

**Expected behavior:**

- Syncthing treats these entries as ignoring the directory node and its contents, not just contents.

### Task 5: Materialize `~/src/.stignore` on the client

**Files:**

- Modify: `users/_modules/syncthing/default.nix`

- [ ] Stop relying on Home Manager folder `ignorePatterns` for `folders.src`.
- [ ] Keep `src_ignore_patterns.nix` as the single policy source.
- [ ] Generate `.stignore` text from that list and ensure `~/src/.stignore` exists declaratively.
- [ ] Preserve the existing Syncthing folder/device wiring for `src`.

**Expected code shape:**

- `ignorePatterns = ...` is removed from the HM folder config.
- A generated `.stignore` file is managed at `~/src/.stignore`.

### Task 6: Apply the ignore list on the server

**Files:**

- Modify: `users/_units/syncthing/default.nix`

- [ ] Reuse the same canonical ignore list for the server-side `src` folder.
- [ ] Configure the server’s NixOS Syncthing folder with `ignorePatterns` so the module applies them through Syncthing’s ignore API.
- [ ] Preserve existing Syncthing folder/device wiring and `src_root` behavior.
- [ ] Keep `.git` syncing intentional by leaving it out of the shared ignore list.

**Expected code shape:**

- The server-side `folders.src` config includes `ignorePatterns = src_ignore_patterns;` sourced from `users/_modules/storage/src_ignore_patterns.nix`.
- No separate hand-managed server `.stignore` source is introduced.

---

## Chunk 3: Review and execute safely

### Task 7: Plan/code review gate via subagent

**Files:**

- Review against all files above.

- [ ] Send this plan and the relevant repo context to a reviewer/planner subagent.
- [ ] Only proceed if the review confirms the chosen approach or suggests small corrections.
- [ ] If the review finds a blocker, fix the plan/implementation approach first.

### Task 8: Implement with minimal scope

**Files:**

- Only files listed in the earlier chunks.

- [ ] Apply the NFS changes first.
- [ ] Apply the Syncthing ignore changes second.
- [ ] Keep changes minimal and consistent with existing repo conventions.

---

## Chunk 4: Verification

### Task 9: Run required repo checks

**Files:**

- Verification only.

- [ ] Run `nix fmt`.
- [ ] Stage the changed files with `git add` so `prek` sees them.
- [ ] Run `prek`.
- [ ] Because Nix files changed, run `nix flake check --all-systems` after earlier checks pass.
- [ ] If any check fails, capture the exact failure and distinguish code issues from known environment-specific flake noise.

### Task 10: Record runtime validation steps

**Files:**

- No required file changes.

- [ ] Report the exact post-deploy checks to confirm the outage is fixed:
  - client: `systemctl status home-lav-.shared.automount home-lav-.shared.mount`
  - client: `findmnt /home/lav/.shared`
  - client: `ls ~/.shared`
  - client: `ls ~`
  - server: `exportfs -v`
  - client/server: verify `.stignore` exists at `~/src/.stignore` and `/srv/syncthing/src/.stignore`
  - Syncthing UI/API: confirm ignored trees are no longer pending and `.git` still syncs.

---

## Risks and rollback notes

- If the NFSv4 pseudo-root change is applied on the server without aligning the client mount path to `/`, the client will likely remain broken.
- If the client mount path changes without the server exporting `fsid=0`, the client will also remain broken.
- `.stignore` is local-only; the client must manage its own file explicitly, while the server must apply the same ignore list through its own local Syncthing configuration.
- Changing ignore patterns will not necessarily delete already-synced junk automatically; one-time cleanup may still be needed if unwanted data already landed.
- If runtime checks show the NFS contract fix works but `ls ~` still feels too sensitive to future outages, a follow-up hardening option is removing `-X` from `users/_modules/cli/eza.nix`.
