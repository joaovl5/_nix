{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  s = my.secrets;
in {
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
      "syncthing_lavpc_pem_cert" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "lavpc_pem_cert" {};
      "syncthing_lavpc_pem_key" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "lavpc_pem_key" {};
      "syncthing_tyrant_pem_cert" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "tyrant_pem_cert" {};
      "syncthing_tyrant_pem_key" = s.mk_secret_user "${s.dir}/syncthing/syncthing.yaml" "tyrant_pem_key" {};
    };
  };
}
