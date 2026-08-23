/*
Representation types:
- "kc" - the formatted key-code style used by `parse-key-code`
- "base" - the "primary" means for representing the type
- <other names> - style for other programs

Adding an apostrophe signals we are not talking about typeable keys,
and instead we're talking of modifiers (e.g. shift, ctrl) - we deem a
modifier any key that normally can't be handled on its own.

If "null" exists in a map, means it doesn't truly map (i.e. it's an
unsupported key.)
*/
rec {
  # when migrating this file elsewhere (not nix), use something to
  # generate these safely without redundancy
  base' = builtins.attrValues kc-to-base';

  kc-to-base' = {
    # keep-sorted start
    "A" = "alt";
    "C" = "ctrl";
    "S" = "shift";
    "X" = "super";
    # keep-sorted end
  };
  kc-to-base = {
    # keep-sorted start
    "'" = "quote";
    "/" = "slash";
    "0" = "0";
    "1" = "1";
    "2" = "2";
    "3" = "3";
    "4" = "4";
    "5" = "5";
    "6" = "6";
    "7" = "7";
    "8" = "8";
    "9" = "9";
    ";" = "semicolon";
    "BKSPC" = "backspace";
    "DELETE" = "delete";
    "DOWN" = "arrow-down";
    "END" = "end";
    "EQUAL" = "=";
    "ESC" = "escape";
    "F1" = "f1";
    "F10" = "f10";
    "F11" = "f11";
    "F12" = "f12";
    "F13" = "f13";
    "F14" = "f14";
    "F15" = "f15";
    "F16" = "f16";
    "F17" = "f17";
    "F18" = "f18";
    "F19" = "f19";
    "F2" = "f2";
    "F20" = "f20";
    "F21" = "f21";
    "F22" = "f22";
    "F23" = "f23";
    "F24" = "f24";
    "F3" = "f3";
    "F4" = "f4";
    "F5" = "f5";
    "F6" = "f6";
    "F7" = "f7";
    "F8" = "f8";
    "F9" = "f9";
    "HOME" = "home";
    "LEFT" = "arrow-left";
    "MINUS" = "-";
    "PGDOWN" = "page-down";
    "PGUP" = "page-up";
    "RET" = "enter";
    "RIGHT" = "arrow-right";
    "SPC" = "space";
    "TAB" = "tab";
    "UP" = "arrow-up";
    "[" = "lbracket";
    "\\" = "inverted-slash";
    "]" = "rbracket";
    "`" = "tick";
    "a" = "a";
    "b" = "b";
    "c" = "c";
    "d" = "d";
    "e" = "e";
    "f" = "f";
    "g" = "g";
    "h" = "h";
    "i" = "i";
    "j" = "j";
    "k" = "k";
    "l" = "l";
    "m" = "m";
    "n" = "n";
    "o" = "o";
    "p" = "p";
    "q" = "q";
    "r" = "r";
    "s" = "s";
    "t" = "t";
    "u" = "u";
    "v" = "v";
    "w" = "w";
    "x" = "x";
    "y" = "y";
    "z" = "z";
    # keep-sorted end
  };
  base-to-fish = {
    # keep-sorted start
    "-" = "minus";
    "0" = "0";
    "1" = "1";
    "2" = "2";
    "3" = "3";
    "4" = "4";
    "5" = "5";
    "6" = "6";
    "7" = "7";
    "8" = "8";
    "9" = "9";
    "=" = "=";
    "a" = "a";
    "arrow-down" = "down";
    "arrow-left" = "left";
    "arrow-right" = "right";
    "arrow-up" = "up";
    "b" = "b";
    "backspace" = "backspace";
    "c" = "c";
    "d" = "d";
    "delete" = "delete";
    "e" = "e";
    "end" = "end";
    "enter" = "enter";
    "escape" = "escape";
    "f" = "f";
    "f1" = "f1";
    "f10" = "f10";
    "f11" = "f11";
    "f12" = "f12";
    "f13" = null;
    "f14" = null;
    "f15" = null;
    "f16" = null;
    "f17" = null;
    "f18" = null;
    "f19" = null;
    "f2" = "f2";
    "f20" = null;
    "f21" = null;
    "f22" = null;
    "f23" = null;
    "f24" = null;
    "f3" = "f3";
    "f4" = "f4";
    "f5" = "f5";
    "f6" = "f6";
    "f7" = "f7";
    "f8" = "f8";
    "f9" = "f9";
    "g" = "g";
    "h" = "h";
    "home" = "home";
    "i" = "i";
    "inverted-slash" = "\\";
    "j" = "j";
    "k" = "k";
    "l" = "l";
    "lbracket" = "[";
    "m" = "m";
    "n" = "n";
    "o" = "o";
    "p" = "p";
    "page-down" = "pagedown";
    "page-up" = "pageup";
    "q" = "q";
    "quote" = "'";
    "r" = "r";
    "rbracket" = "]";
    "s" = "s";
    "semicolon" = ";";
    "slash" = "/";
    "space" = "space";
    "t" = "t";
    "tab" = "tab";
    "tick" = "`";
    "u" = "u";
    "v" = "v";
    "w" = "w";
    "x" = "x";
    "y" = "y";
    "z" = "z";
    # keep-sorted end
  };
  base-to-fish' = {
    # keep-sorted start
    "alt" = "alt";
    "ctrl" = "ctrl";
    "shift" = "shift";
    "super" = "super";
    # keep-sorted end
  };
}
