{
  self,
  inputs,
  mylib,
  system,
  pkgs,
  ...
} @ args: let
  testSshSeed = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f";
  test_ssh_key =
    pkgs.runCommand "backup-test-ssh-key" {
      nativeBuildInputs = [
        pkgs.openssh
        (pkgs.python3.withPackages (ps: [ps.cryptography]))
      ];
    } ''
      mkdir -p "$out"
      OUT="$out" python <<'PY'
      import os
      from cryptography.hazmat.primitives import serialization
      from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

      out = os.environ["OUT"]
      seed = bytes.fromhex("${testSshSeed}")
      key = Ed25519PrivateKey.from_private_bytes(seed)

      private_bytes = key.private_bytes(
          encoding=serialization.Encoding.PEM,
          format=serialization.PrivateFormat.OpenSSH,
          encryption_algorithm=serialization.NoEncryption(),
      )
      public_bytes = key.public_key().public_bytes(
          encoding=serialization.Encoding.OpenSSH,
          format=serialization.PublicFormat.OpenSSH,
      )

      with open(f"{out}/id_ed25519", "wb") as fh:
          fh.write(private_bytes)
      with open(f"{out}/id_ed25519.pub", "wb") as fh:
          fh.write(public_bytes + b"\n")
      PY

      chmod 600 "$out/id_ed25519"
      chmod 644 "$out/id_ed25519.pub"
      ssh-keygen -y -f "$out/id_ed25519" > "$TMPDIR/derived.pub"
      cmp "$TMPDIR/derived.pub" "$out/id_ed25519.pub"
    '';
in
  # Two-node topology: coordinator backs up local fixtures into repo A, promotes
  # eligible snapshots to repo B over SFTP on storage, then exercises remote
  # forget/prune/check without regressing unrelated snapshot families.
  mylib.tests.mk_test {
    name = "backup_promotion";
    python_module_name = "backup_promotion";

    node.pkgsReadOnly = false;
    node.specialArgs = {
      inherit self inputs mylib system test_ssh_key;
    };

    nodes.coordinator = import ./coordinator.nix args;
    nodes.storage = import ./storage.nix args;
  }
