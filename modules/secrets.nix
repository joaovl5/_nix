{
  mysecrets,
  lib,
  ...
}: {
  imports = [
    # imports private secrets sops module
    # this will leverage sops-nix
    "${mysecrets}/sops.nix"
  ];

  # stores public data (public keys)
  # anything else will use sops-nix
  options.public = let
    inherit (lib) mkDefault;
    public_data = import "${mysecrets}/public.nix";
  in {
    ssh_key = mkDefault public_data.ssh_key.main;
    age_key = mkDefault public_data.age_key.main;
  };

  config.sops = {
    defaultSopsFile = "${mysecrets}/.sops.yaml";

    # make files for these
    # how should they appear there?
    # - injected in iso?
    # - how to persist declaratively?
    age.sshKeyPaths = ["/boot/host_key"];
    age.keyFile = "/boot/age_sops_key.txt";

    secrets = {
      "password_hash" = {
        sopsFile = "${mysecrets}/secrets/password_hashes.yaml";
        key = "main";
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };
      "personal_ssh_key" = {
        sopsFile = "${mysecrets}/secrets/ssh_keys.yaml";
        key = "personal_ssh_key";
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };
}
