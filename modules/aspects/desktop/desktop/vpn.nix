_: {
  den.aspects.desktop.nixos = _: {
    services.mullvad-vpn = {
      enable = true;
      gui.enable = true;
    };
  };
}
