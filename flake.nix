{
  description = "lav nixos config";

  outputs = _inputs: removeAttrs (import ./default.nix) ["flake-file"];
}
