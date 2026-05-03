let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./eww)
  ];
in
  combine_modules modules
