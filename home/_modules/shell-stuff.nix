{
  config,
  lib,
  mylib,
  ...
}: let
  t = lib.types;
  mk = lib.mkOption;
  to-arg = lib.escapeShellArg;
  join-sep = lib.concatStringsSep;
  mk-t = t: mk {type = t;};
  mk-t-d = t: d:
    mk {
      type = t;
      default = d;
    };
  abbrs = config.shell-abbrs;
  keys = config.shell-keys;

  inherit (mylib) kc-maps;
in {
  options = {
    shell-abbrs = mk-t-d (t.attrsOf t.str) {};
    shell-keys = mk {
      default = {};
      type = t.attrsOf (t.submodule
        {
          options = {
            key = mk-t t.str;
            modifiers = let
              mod-enum =
                t.enum
                kc-maps.base';
            in
              mk-t-d
              (t.listOf mod-enum) [];
            action = mk-t t.str;
          };
        });
    };
  };
  config = {
    programs.fish = {
      shellAbbrs = abbrs;
      interactiveShellInit = let
        to-fish-mod = x:
          (kc-maps.base-to-fish'.${x}
           or (throw "Unknown modifier `${x}`"))
          + "-"; # add dash for prefix, e.g. ctrl-
        get-kc-mods = v:
          join-sep "" (map to-fish-mod v.modifiers);
        get-base-kc = x: let
          base-kc = kc-maps.base-to-fish.${x}
          or (throw "Unknown base key `${x}`");
        in
          if base-kc == null
          then throw "Key `${x}` can't be used in fish"
          else base-kc;

        get-kc = v: "${get-kc-mods v}${get-base-kc v.key}";
        get-key-action = v: to-arg "${v.action}";

        # let's make this intermediary map so we key things by their
        # resolved keycodes. this is for detecting duplicate keybinds
        #
        # end result is an attrset of the same:
        # {"<key code>" = {"name": "<attrset name>"; "action": ...}}
        binds-by-kc =
          lib.foldlAttrs
          (
            # `agg` stands for "aggregate"
            agg: name: value: let
              kc = get-kc value;
              action = get-key-action value;
            in
              if agg ? ${kc}
              then
                throw
                (join-sep " " [
                  "Bindings `${agg.${kc}.name}` and `${name}`"
                  "resolve to the same key code `${kc}`"
                ])
              else
                agg
                // {
                  ${kc} = {
                    inherit name;
                    inherit action;
                  };
                }
          )
          {}
          keys;

        key-repr = k: v: let
          # do thing for safe comments if someone is stupid enough to
          # add a newline to a nix attrset key
          safe-name =
            lib.replaceStrings
            ["\r" "\n"]
            ["\\r" "\\n"]
            v.name;
        in
          # fish
          ''bind ${to-arg k} ${v.action} # key name: ${safe-name}'';
      in
        join-sep "\n" (lib.mapAttrsToList key-repr binds-by-kc);
    };
  };
}
