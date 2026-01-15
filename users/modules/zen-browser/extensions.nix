{
  inputs,
  system,
  ...
}: {
  extensions = with inputs.firefox-addons.packages.${system}; [
    ublock-origin
    bitwarden
  ];
  settings = {
    # some addons have declarative cfg support
    "uBlock0@raymondhill.net".settings = {
      selectedFilterLists = [
        "ublock-filters"
        "ublock-badware"
        "ublock-privacy"
        "ublock-quick-fixes"
        "ublock-unbreak"
      ];
    };
  };
}
