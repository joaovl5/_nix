_: {
  den.aspects.desktop.nixos = {inputs, ...}: {
    nixpkgs.overlays = [
      inputs.whisper-overlay.overlays.default
    ];
  };
}
