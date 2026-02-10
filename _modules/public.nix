{inputs, ...}: let
  mysecrets = inputs.mysecrets;
  public_data = import "${mysecrets}/public.nix";
in {
  ssh_key = public_data.ssh_key.main;
  age_key = public_data.age_key.main;
  emails = public_data.emails;
  links = public_data.links;
}
