let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./anyrun)
  ];
in
  combine_modules modules
