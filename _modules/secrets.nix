{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (inputs) mysecrets;
  cfg = config.my.nix;
in {
  imports = [
    # imports private secrets sops module
    # this will leverage sops-nix
    "${mysecrets}/sops.nix"
  ];

  # stores public data (public keys)
  # anything else will use sops-nix

  config.sops = lib.mkForce {
    defaultSopsFile = "${mysecrets}/.sops.yaml";

    # make files for these
    # how should they appear there?
    # - injected in iso?
    # - how to persist declaratively?
    age.keyFile = "/root/.age/key.txt";

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
