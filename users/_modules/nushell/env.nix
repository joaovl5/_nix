{
  hm = {
    nixos_config,
    mylib,
    lib,
    ...
  }: let
    s = (mylib.use nixos_config).secrets;
    mk_secret = name: path: ''$env.${name} = (cat ${path})'';
  in {
    programs.nushell.envFile.text = ''
      ${lib.readFile ./src/vars.nu}

      ${mk_secret "OPENAI_KEY" (s.secret_path "openai_key")}
      ${mk_secret "OPENAI_API_KEY" (s.secret_path "openai_key")}
    '';
  };
}
