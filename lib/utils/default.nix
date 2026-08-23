{lib, ...}: rec {
  kc-maps = import ./kc-maps.nix;

  /*

  Parse key-code in the format similar to neovim/emacs:
  - "C-a" -> ctrl+a
  - "C-S-a" -> ctrl+shift+a
  - "A-g" -> alt+g
  - "A-S-g" -> alt+shift+g
  - "C-X-a" -> ctrl+super+a - is NOT shift!

  Important distinctions:
  - "X" means super to avoid confusion
  - "S" means shift; uppercase things like "C-A" won't be supported
  - modifier order doesn't matter, but should remain joined w. dashes

  */
  parse-key-code = key-code: let
    kc-parts = lib.splitString "-" key-code;
    raw-base = lib.last kc-parts;
    raw-mods = lib.init kc-parts;
    parse-mod = x:
      kc-maps.kc-to-base'.${x} or (throw "Invalid modifier `${x}`");
    parse-base = x:
      kc-maps.kc-to-base.${x} or (throw "Invalid base key `${x}`");
  in
    if (builtins.any (part: part == "") kc-parts)
    then throw "Invalid key code `${key-code}`"
    else {
      key = parse-base raw-base;
      modifiers = map parse-mod raw-mods;
    };
  mk-key = raw-key-code: action: let
    parsed-kc = parse-key-code raw-key-code;
  in {
    inherit (parsed-kc) key modifiers;
    inherit action;
  };
  # a slightly insane shorthand for `mk-key`
  k- = mk-key;
}
