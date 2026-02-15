{mylib, ...}: let
  # s = import ../_lib/secrets.nix args;
  # TODO: ^1 - move usages of getting secret paths to `mylib.secrets`
  # TODO: ^1 - move all usages of libs to use input mylib
  s = mylib.secrets;
  # s = (import mylib args).secrets;
in {
  imports = [
    "${s.private_source}/sops.nix"
  ];

  sops = {
    defaultSopsFile = "${s.private_source}/.sops.yaml";
    age.keyFile = "/root/.age/key.txt";

    secrets = {
      "password_hash" = s.mk_secret "${s.dir}/password_hashes.yaml" "main" {neededForUsers = true;};
      "password_hash_server" = s.mk_secret "${s.dir}/password_hashes.yaml" "server" {neededForUsers = true;};
      "personal_ssh_key" = s.mk_secret "${s.dir}/ssh_keys.yaml" "personal_ssh_key" {};

      # api stuff
      "openai_key" = s.mk_secret_user "${s.dir}/api_keys.yaml" "openai" {};
      # "openai_key" = {
      #   sopsFile = "${s.private_source}/secrets/api_keys.yaml";
      #   key = "openai";
      #   owner = "${cfg.username}";
      # };

      # syncthing-related stuff
      "syncthing_server_id" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "server_id" {};
      "syncthing_gui_user" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "server_gui_user" {};
      "syncthing_gui_password" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "server_gui_password" {};
      "syncthing_pem_cert" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "pem_cert" {};
      "syncthing_pem_key" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "pem_key" {};
    };
  };
}
