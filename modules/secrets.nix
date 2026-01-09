{
  inputs,
  config,
  lib,
  ...
}: let
  mysecrets = inputs.mysecrets;
  cfg = config.my_nix;
in {
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

  config.sops = lib.mkForce {
    defaultSopsFile = "${mysecrets}/.sops.yaml";

    # make files for these
    # how should they appear there?
    # - injected in iso?
    # - how to persist declaratively?
    age.sshKeyPaths = ["/root/host_key"];
    age.keyFile = "/root/age_sops_key.txt";

    secrets = {
      "password_hash" = {
        sopsFile = "${mysecrets}/secrets/password_hashes.yaml";
        key = "main";
        owner = "root";
        group = "root";
        mode = "0400";
        neededForUsers = true;
      };

      "password_hash_server" = {
        sopsFile = "${mysecrets}/secrets/password_hashes.yaml";
        key = "server";
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

      # api stuff
      "openai_key" = {
        sopsFile = "${mysecrets}/secrets/api_keys.yaml";
        key = "openai";
        owner = "${cfg.username}";
      };

      # syncthing-related stuff
      syncthing_server_id = {
        sopsFile = "${mysecrets}/secrets/syncthing/syncthing.yaml";
        key = "server_id";
        owner = "${cfg.username}";
      };
      syncthing_gui_user = {
        sopsFile = "${mysecrets}/secrets/syncthing/syncthing.yaml";
        key = "server_gui_user";
        owner = "${cfg.username}";
      };
      syncthing_gui_password = {
        sopsFile = "${mysecrets}/secrets/syncthing/syncthing.yaml";
        key = "server_gui_password";
        owner = "${cfg.username}";
      };
      syncthing_pem_cert = {
        sopsFile = "${mysecrets}/secrets/syncthing/syncthing.yaml";
        key = "pem_cert";
        owner = "${cfg.username}";
      };
      syncthing_pem_key = {
        sopsFile = "${mysecrets}/secrets/syncthing/syncthing.yaml";
        key = "pem_key";
        owner = "${cfg.username}";
      };
    };
  };
}
