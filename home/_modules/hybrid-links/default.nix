{
  config,
  lib,
  ...
}: let
  inherit (lib) attrValues concatLists mapAttrs' mkIf mkOption nameValuePair unique;
  inherit (lib.strings) hasPrefix removePrefix removeSuffix;
  t = lib.types;

  cfg = config.hybrid-links;

  normalize_absolute = path: removeSuffix "/" (toString path);

  is_nested_under = root: path:
    path == root || hasPrefix "${root}/" path;

  is_directory = path: let
    path_str = toString path;
    read_dir = builtins.tryEval (builtins.readDir path_str);
  in
    builtins.pathExists path_str && read_dir.success;

  target_from = to:
    removePrefix "~/" to;

  source_from = link:
    if
      link.hybrid
      && cfg.flake_root != null
      && cfg.flake_path != null
      && cfg.flake_path != ""
      && hasPrefix "/" cfg.flake_path
    then let
      flake_root = normalize_absolute cfg.flake_root;
      from = normalize_absolute link.from;
      relative_path =
        if from == flake_root
        then ""
        else removePrefix "${flake_root}/" from;
      checkout_path =
        if relative_path == ""
        then cfg.flake_path
        else "${cfg.flake_path}/${relative_path}";
    in
      config.lib.file.mkOutOfStoreSymlink checkout_path
    else link.from;

  link_assertions =
    concatLists
    (lib.mapAttrsToList (
        name: link: let
          target = target_from link.to;
          from = normalize_absolute link.from;
          flake_root =
            if cfg.flake_root == null
            then null
            else normalize_absolute cfg.flake_root;
        in
          [
            {
              assertion = hasPrefix "~/" link.to;
              message = "hybrid-links.links.${name}.to must start with '~/'.";
            }
            {
              assertion = target != "";
              message = "hybrid-links.links.${name}.to must not resolve to an empty home-relative path.";
            }
            {
              assertion = !(hasPrefix "/" target);
              message = "hybrid-links.links.${name}.to must stay home-relative after stripping '~/'.";
            }
            {
              assertion = (!link.recursive) || is_directory link.from;
              message = "hybrid-links.links.${name}.from must point to a directory when recursive = true.";
            }
          ]
          ++ lib.optionals link.hybrid [
            {
              assertion = cfg.flake_root != null;
              message = "hybrid-links.links.${name} requires hybrid-links.flake_root when hybrid = true.";
            }
            {
              assertion = cfg.flake_path != null && cfg.flake_path != "" && hasPrefix "/" cfg.flake_path;
              message = "hybrid-links.links.${name} requires hybrid-links.flake_path to be a non-empty absolute path when hybrid = true.";
            }
            {
              assertion = flake_root != null && is_nested_under flake_root from;
              message = "hybrid-links.links.${name}.from must be equal to or nested under hybrid-links.flake_root when hybrid = true.";
            }
          ]
      )
      cfg.links)
    ++ [
      {
        assertion = let
          targets = map (link: link.to) (attrValues cfg.links);
        in
          builtins.length targets == builtins.length (unique targets);
        message = "hybrid-links.links must not contain duplicate 'to' values.";
      }
    ];

  home_files =
    mapAttrs' (
      name: link:
        nameValuePair "hybrid-links/${name}" {
          source = source_from link;
          target = target_from link.to;
          inherit (link) recursive;
          inherit (link) force;
        }
    )
    cfg.links;
in {
  options.hybrid-links = {
    enable = mkOption {
      type = t.bool;
      default = true;
    };

    flake_root = mkOption {
      type = t.nullOr (t.oneOf [t.path t.str]);
      default = null;
    };

    flake_path = mkOption {
      type = t.nullOr t.str;
      default = null;
    };

    links = mkOption {
      type = t.attrsOf (t.submodule {
        options = {
          from = mkOption {
            type = t.oneOf [t.path t.str];
          };

          to = mkOption {
            type = t.str;
          };

          hybrid = mkOption {
            type = t.bool;
            default = true;
          };

          recursive = mkOption {
            type = t.bool;
            default = true;
          };

          force = mkOption {
            type = t.bool;
            default = true;
          };
        };
      });
      default = {};
    };
  };

  config = mkIf cfg.enable {
    assertions = link_assertions;
    home.file = home_files;
  };
}
