{lib, ...}: {
  stage1_greeting = ''
    ${lib.readFile ./assets/stage1_greeting.txt}

    (stage 1)
  '';

  stage2_greeting = ''
    ${lib.readFile ./assets/stage2_greeting.txt}

    (stage 2)
  '';

  generate_greeting = {system_title, ...}: ''
    ${system_title}


  '';
}
