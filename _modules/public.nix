{inputs, ...}: let
  inherit (inputs) mysecrets;
  public_data = import "${mysecrets}/public.nix";
in {
  ssh_key = public_data.ssh_key.main;
  age_key = public_data.age_key.main;
  inherit (public_data) emails;
  inherit (public_data) links;
}
