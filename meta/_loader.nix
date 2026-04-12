{lib}: let
  is_import_source = value: builtins.typeOf value == "path";

  source_label = source: let
    type = builtins.typeOf source;
  in
    if type == "path"
    then builtins.toString source
    else if type == "set" && source ? name
    then "meta module `${source.name}`"
    else if type == "lambda"
    then "<function>"
    else "<${type}>";

  resolve_source = source: let
    imported =
      if builtins.typeOf source == "path"
      then import source
      else source;
    module =
      if builtins.typeOf imported == "lambda"
      then imported {inherit lib;}
      else imported;
  in
    if !lib.isAttrs module
    then throw "meta module source ${source_label source} must evaluate to an attrset."
    else module;

  normalize_module = module: let
    imports = module.imports or [];
    options = module.options or {};
    consumer_attrs = builtins.removeAttrs module ["name" "imports" "options"];
    unsupported_keys =
      builtins.filter
      (key: !lib.isFunction consumer_attrs.${key})
      (builtins.attrNames consumer_attrs);
    invalid_imports = builtins.filter (value: !is_import_source value) imports;
  in
    if !module ? name
    then throw "meta module is missing the canonical `name` field."
    else if !lib.isString module.name || module.name == ""
    then throw "meta module name must be a non-empty string."
    else if !lib.isList imports
    then throw "meta module `${module.name}` imports must be a list."
    else if !lib.isAttrs options
    then throw "meta module `${module.name}` options must be an attrset."
    else if unsupported_keys != []
    then throw "meta module `${module.name}` only accepts the canonical `name`, top-level `imports`, top-level `options`, and consumer functions. Unsupported keys: ${lib.concatStringsSep ", " unsupported_keys}"
    else if invalid_imports != []
    then throw "meta module `${module.name}` imports must contain only file paths."
    else module;

  load_source = state: expected_name: source: let
    module = normalize_module (resolve_source source);
    inherit (module) name;
    current_stack = state.stack;
    next_stack = current_stack ++ [name];
    label = source_label source;
  in
    if expected_name != null && expected_name != name
    then throw "meta module registry key `${expected_name}` must match canonical name `${name}`."
    else if builtins.elem name current_stack
    then throw "meta module import cycle detected: ${lib.concatStringsSep " -> " (current_stack ++ [name])}"
    else if builtins.hasAttr name state.registry
    then let
      previous = state.sources.${name};
    in
      if previous == label
      then state
      else throw "duplicate meta module `${name}` loaded from ${label}; already loaded from ${previous}."
    else let
      state_with_current = state // {stack = next_stack;};
      imported_state =
        builtins.foldl' (
          acc: import_source:
            load_source acc null import_source
        )
        state_with_current
        module.imports;
      state_after_imports = imported_state // {stack = current_stack;};
    in
      state_after_imports
      // {
        registry = state_after_imports.registry // {${name} = module;};
        order = state_after_imports.order ++ [name];
        sources = state_after_imports.sources // {${name} = label;};
        stack = current_stack;
      };
in
  roots:
    if !lib.isAttrs roots
    then throw "meta module roots must be an attrset."
    else
      builtins.foldl' (
        state: name:
          load_source state name roots.${name}
      ) {
        registry = {};
        order = [];
        sources = {};
        stack = [];
      } (builtins.attrNames roots)
