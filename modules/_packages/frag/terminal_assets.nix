{
  pkgs,
  lib ? pkgs.lib,
  zjstatus,
}: let
  starship_toml = (pkgs.formats.toml {}).generate "frag-starship.toml" ((import ../../aspects/desktop/cli/starship/settings.nix {}).lav.cli.starship.settings {inherit lib;});

  tmux_plugin_name = "better-mouse-mode";
  tmux_config = pkgs.writeText "frag-tmux.conf" ''
    ${builtins.readFile ../../aspects/desktop/cli/multiplexer/tmux/tmux.conf}

    run-shell ~/.config/tmux/plugins/${tmux_plugin_name}/scroll_copy_mode.tmux
  '';
in
  pkgs.runCommand "frag-terminal-assets" {} ''
    shared_root=$out/share/frag/shared-assets

    mkdir -p \
      "$shared_root/.config/fish/conf.d" \
      "$shared_root/.config/zellij" \
      "$shared_root/.config/tmux/plugins" \
      "$shared_root/.local/share/zellij/plugins"

    cp ${../../aspects/desktop/cli/shell/fish/src/frag_init.fish} \
      "$shared_root/.config/fish/conf.d/frag_init.fish"
    cp ${../../aspects/desktop/cli/shell/fish/src/container_safe_vars.fish} \
      "$shared_root/.config/fish/conf.d/container_safe_vars.fish"
    cp ${../../aspects/desktop/cli/shell/fish/src/container_safe_functions.fish} \
      "$shared_root/.config/fish/conf.d/container_safe_functions.fish"
    cp ${starship_toml} "$shared_root/.config/starship.toml"

    cp -r ${../../aspects/desktop/cli/multiplexer/zellij/config}/. \
      "$shared_root/.config/zellij"
    cp ${zjstatus}/bin/zjstatus.wasm \
      "$shared_root/.local/share/zellij/plugins/zjstatus.wasm"

    cp ${tmux_config} "$shared_root/.config/tmux/tmux.conf"
    mkdir -p "$shared_root/.config/tmux/plugins/${tmux_plugin_name}"
    cp -r ${pkgs.tmuxPlugins.better-mouse-mode}/share/tmux-plugins/${tmux_plugin_name}/. \
      "$shared_root/.config/tmux/plugins/${tmux_plugin_name}"
  ''
