{
  lib,
  pkgs,
  ...
}: {
  stage1_greeting = ''
    ${lib.readFile ./assets/stage1_greeting.txt}

    (stage 1)
  '';

  stage2_greeting = ''
    ${lib.readFile ./assets/stage2_greeting.txt}

    (stage 2)
  '';

  generate_greeting = let
    date_drv = ''
      ${pkgs.runCommand "timestamp" {env.when = builtins.currentTime;}
        "echo -n `date -d @$when +%Y-%m-%d_%H-%M-%S` > $out"}'';
    date_val = lib.readFile date_drv;
  in
    {
      system_title,
      show_qr ? true,
    }: ''
      ${system_title}


    '';
}
