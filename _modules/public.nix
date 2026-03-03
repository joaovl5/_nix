{inputs, ...}: let
  inherit (inputs) mysecrets;
  public_data = import "${mysecrets}/public.nix";
in {
  ssh_key = public_data.ssh_key.main;
  age_key = public_data.age_key.main;
  wireguard_key = public_data.wireguard_key.main;
  wireguard_key_vpn = public_data.wireguard_key.vpn;
  wireguard_key_tyrant = public_data.wireguard_key.tyrant;
  inherit (public_data) emails;
  inherit (public_data) links;
}
