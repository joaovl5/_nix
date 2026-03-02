{self, ...}: {
  imports =
    self._utils.hosts.shared_modules
    ++ [
      ../../systems/astral
      ../../users/lav.nix
      ../base_node.nix
    ];
}
