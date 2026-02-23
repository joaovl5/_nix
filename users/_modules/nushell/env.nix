{
  hm = {
    nixos_config,
    lib,
    ...
  }: let
    inherit (nixos_config.sops) secrets;
    mk_secret = name: path: ''$env.${name} = (cat ${path})'';
  in {
    programs.nushell.envFile.text = ''
      ${lib.readFile ./src/vars.nu}

      ${mk_secret "OPENAI_KEY" "${secrets.openai_key.path}"}
      ${mk_secret "OPENAI_API_KEY" "${secrets.openai_key.path}"}
    '';
  };
}
