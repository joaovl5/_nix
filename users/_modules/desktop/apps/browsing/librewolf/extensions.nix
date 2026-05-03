{lib, ...}: let
  # base extension
  _e = url: opts: id: {
    ${id} =
      {
        install_url = url;
        installation_mode = "force_installed";
      }
      // opts;
  };

  # firefox web store extensions
  _E = suffix: opts: id: (_e "https://addons.mozilla.org/firefox/downloads/file/${suffix}" opts id);
in
  lib.mkMerge [
    (_E "4691016/canvasblocker-1.12.xpi" {} "CanvasBlocker@kkapsner.de")
    (_E "4675310/ublock_origin-1.69.0.xpi" {} "uBlock0@raymondhill.net")
    (_E "4664623/bitwarden_password_manager-2025.12.1.xpi" {} "{446900e4-71c2-419f-a6a7-df9c091e268b}")
    (_E "4613339/sidebery-5.4.0.xpi" {} "{3c078156-979c-498b-8990-85f7987dd929}")
  ]
