{
  u,
  host_name,
  destinations,
  policies,
  host_items,
  unit_items,
}: let
  mk_items = unit_name: items:
    map (item_name: {
      source_host = host_name;
      inherit unit_name item_name;
      item = items.${item_name};
    }) (builtins.attrNames items);

  host_owned_items = mk_items "host" host_items;

  unit_owned_items = builtins.concatLists (map (
    unit_name: mk_items unit_name unit_items.${unit_name}
  ) (builtins.attrNames unit_items));

  collected_items = host_owned_items ++ unit_owned_items;
in {
  inherit host_owned_items unit_owned_items;
  inherit collected_items;
  resolved_items = u.backup.resolve_items {
    inherit host_name destinations policies;
    items = collected_items;
  };
}
