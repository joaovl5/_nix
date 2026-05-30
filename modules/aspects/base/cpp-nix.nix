_: {
  den.aspects.cpp-nix.nixos = _: {
    nix.settings = {
      experimental-features = [
        "blake3-hashes"
        "ca-derivations"
        "dynamic-derivations"
        "external-builders"
        "fetch-closure"
        "git-hashing"
      ];
    };
  };
}
