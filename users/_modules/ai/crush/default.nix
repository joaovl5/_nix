{
  hm = {
    inputs,
    pkgs,
    ...
  }: {
    imports = [
      pkgs.nur.repos.charmbracelet.modules.homeManager.crush
    ];
    programs.crush = {
      enable = true;
      settings = {
        options = {
          skills_paths = [
            "${inputs.anthropic-skills}/skills"
          ];
        };
        # lsp = {
        #   go = {
        #     command = "gopls";
        #     enabled = true;
        #   };
        #   nix = {
        #     command = "nil";
        #     enabled = true;
        #   };
        #   python = {
        #     command = "basedpyright";
        #     enabled = true;
        #   };
        # };
        options = {
          context_paths = ["/etc/nixos/configuration.nix"];
          tui = {compact_mode = true;};
          debug = false;
        };
      };
    };
  };
}
