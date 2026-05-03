{
  mylib,
  lib,
  pkgs,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  inherit (o) t;

  inherit
    (lib)
    all
    any
    concatMap
    concatMapStrings
    escapeShellArg
    filterAttrs
    hasInfix
    listToAttrs
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionalAttrs
    splitString
    unique
    ;

  cfg = config.my.network_namespaces;

  Protocol = t.enum ["tcp" "udp" "both"];
  IPFamily = t.enum ["ipv4" "ipv6"];

  PortMapping = t.submodule (_: {
    options = {
      from = mkOption {
        type = t.int;
        description = "Host port to expose.";
      };
      to = mkOption {
        type = t.int;
        description = "Port inside the network namespace.";
      };
      protocol = mkOption {
        type = Protocol;
        default = "tcp";
        description = "Transport protocol to expose.";
      };
    };
  });

  OpenPort = t.submodule (_: {
    options = {
      port = mkOption {
        type = t.int;
        description = "Port to expose on the backend interface.";
      };
      protocol = mkOption {
        type = Protocol;
        default = "both";
        description = "Transport protocol to expose on the backend interface.";
      };
    };
  });

  BlockedDoHEndpoint = t.submodule (_: {
    options = {
      family = mkOption {
        type = IPFamily;
        default = "ipv4";
        description = "Address family for the explicit DNS-over-HTTPS endpoint block.";
      };
      address = mkOption {
        type = t.nullOr t.str;
        default = null;
        description = "Blocked endpoint address.";
      };
      port = mkOption {
        type = t.nullOr t.int;
        default = null;
        description = "Blocked endpoint port.";
      };
    };
  });

  BackendWireguard = t.submodule (_: {
    options = {
      config_file = mkOption {
        type = t.nullOr t.str;
        default = null;
        description = "WireGuard config file applied inside the namespace.";
      };
      interface_name = mkOption {
        type = t.str;
        default = "wg0";
        description = "WireGuard interface name created inside the namespace.";
      };
    };
  });

  NamespaceAddresses = t.submodule (_: {
    options = {
      host_v4 = mkOption {
        type = t.str;
        default = "10.15.0.5";
        description = "IPv4 address on the host side of the namespace veth.";
      };
      namespace_v4 = mkOption {
        type = t.str;
        default = "10.15.0.1";
        description = "IPv4 address on the namespace side of the veth.";
      };
      host_v6 = mkOption {
        type = t.nullOr t.str;
        default = null;
        description = "Optional IPv6 address on the host side of the namespace veth.";
      };
      namespace_v6 = mkOption {
        type = t.nullOr t.str;
        default = null;
        description = "Optional IPv6 address on the namespace side of the veth.";
      };
    };
  });

  NetworkNamespace = t.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "the ${name} network namespace";

      backend = {
        type = mkOption {
          type = t.enum ["none" "wireguard"];
          default = "none";
          description = "Backend applied after the namespace core exists.";
        };
        wireguard = mkOption {
          type = BackendWireguard;
          default = {};
          description = "WireGuard backend settings.";
        };
      };

      addresses = mkOption {
        type = NamespaceAddresses;
        default = {};
        description = "Addresses used for host-to-namespace connectivity.";
      };

      dns = {
        servers = mkOption {
          type = t.listOf t.str;
          default = [];
          description = "Resolvers written to /etc/netns/<name>/resolv.conf.";
        };
        strict = {
          enable = mkEnableOption "strict DNS policy for the namespace";
          block_doh_endpoints = mkOption {
            type = t.listOf BlockedDoHEndpoint;
            default = [];
            description = "Explicit DNS-over-HTTPS endpoints to reject.";
          };
        };
      };

      services = mkOption {
        type = t.listOf t.str;
        default = [];
        description = "Systemd services to run inside this namespace.";
      };

      accessible_from = mkOption {
        type = t.listOf t.str;
        default = [];
        description = "Subnets or addresses that should return through the host veth instead of the backend default route.";
      };

      port_mappings = mkOption {
        type = t.listOf PortMapping;
        default = [];
        description = "Host-to-namespace port mappings.";
      };

      open_vpn_ports = mkOption {
        type = t.listOf OpenPort;
        default = [];
        description = "Ports allowed on the backend VPN interface inside the namespace.";
      };
    };
  });

  enabled_namespaces = filterAttrs (_: namespace: namespace.enable) cfg;
  enabled_namespace_names = builtins.attrNames enabled_namespaces;
  enabled_namespace_values = builtins.attrValues enabled_namespaces;
  enabled_service_names = concatMap (namespace: namespace.services) enabled_namespace_values;

  protocols_for = protocol:
    if protocol == "both"
    then ["tcp" "udp"]
    else [protocol];

  plain_address = address: builtins.head (splitString "/" address);

  normalized_interface_cidr = family: address:
    if hasInfix "/" address
    then address
    else if family == "ipv4"
    then "${address}/24"
    else "${address}/64";

  normalized_host_cidr = family: address:
    if hasInfix "/" address
    then address
    else if family == "ipv4"
    then "${address}/32"
    else "${address}/128";

  family_for_address = address:
    if hasInfix ":" address
    then "ipv6"
    else "ipv4";

  namespace_has_ipv6 = namespace:
    namespace.addresses.host_v6 != null || namespace.addresses.namespace_v6 != null;

  port_valid = port: port >= 1 && port <= 65535;

  nat_chain_name = name: "MYNS-${name}-NAT";
  forward_chain_name = name: "MYNS-${name}-FWD";
  dns_chain_name = name: "MYNS-${name}-DNS";
  vpn_chain_name = name: "MYNS-${name}-VPN";

  host_mapping_commands = family: namespace_name: namespace: let
    tool =
      if family == "ipv4"
      then "\"$iptables\""
      else "\"$ip6tables\"";
    chain = nat_chain_name namespace_name;
    namespace_address =
      if family == "ipv4"
      then plain_address namespace.addresses.namespace_v4
      else plain_address namespace.addresses.namespace_v6;
  in
    concatMapStrings (
      mapping:
        concatMapStrings (protocol: let
          destination =
            if family == "ipv4"
            then "${namespace_address}:${toString mapping.to}"
            else "[${namespace_address}]:${toString mapping.to}";
        in ''
          ensure_host_rule ${tool} nat ${chain} -p ${protocol} --dport ${toString mapping.from} -j DNAT --to-destination ${destination}
        '') (protocols_for mapping.protocol)
    )
    namespace.port_mappings;

  host_forward_commands = family: namespace_name: namespace: let
    tool =
      if family == "ipv4"
      then "\"$iptables\""
      else "\"$ip6tables\"";
    chain = forward_chain_name namespace_name;
    namespace_address =
      if family == "ipv4"
      then plain_address namespace.addresses.namespace_v4
      else plain_address namespace.addresses.namespace_v6;
  in
    concatMapStrings (
      mapping:
        concatMapStrings (protocol: ''
          ensure_host_rule ${tool} filter ${chain} -o "$host_veth" -p ${protocol} -d ${namespace_address} --dport ${toString mapping.to} -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
          ensure_host_rule ${tool} filter ${chain} -i "$host_veth" -p ${protocol} -s ${namespace_address} --sport ${toString mapping.to} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        '') (protocols_for mapping.protocol)
    )
    namespace.port_mappings;

  dns_allow_commands = family: namespace_name: namespace: let
    tool =
      if family == "ipv4"
      then "\"$iptables\""
      else "\"$ip6tables\"";
    chain = dns_chain_name namespace_name;
    matching_servers = builtins.filter (server: family_for_address server == family) namespace.dns.servers;
  in
    concatMapStrings (
      server:
        concatMapStrings (protocol: ''
          ensure_netns_rule "$ns" ${tool} filter ${chain} -p ${protocol} -d ${server} --dport 53 -j ACCEPT
        '') ["tcp" "udp"]
    )
    matching_servers;

  dns_block_commands = family: namespace_name: namespace: let
    tool =
      if family == "ipv4"
      then "\"$iptables\""
      else "\"$ip6tables\"";
    chain = dns_chain_name namespace_name;
    matching_endpoints = builtins.filter (endpoint: endpoint.family == family) namespace.dns.strict.block_doh_endpoints;
  in ''
    ensure_netns_rule "$ns" ${tool} filter ${chain} -p tcp --dport 53 -j REJECT
    ensure_netns_rule "$ns" ${tool} filter ${chain} -p udp --dport 53 -j REJECT
    ensure_netns_rule "$ns" ${tool} filter ${chain} -p tcp --dport 853 -j REJECT
    ensure_netns_rule "$ns" ${tool} filter ${chain} -p udp --dport 853 -j REJECT
    ${concatMapStrings (
        endpoint: ''
          ensure_netns_rule "$ns" ${tool} filter ${chain} -p tcp -d ${endpoint.address} --dport ${toString endpoint.port} -j REJECT
          ensure_netns_rule "$ns" ${tool} filter ${chain} -p udp -d ${endpoint.address} --dport ${toString endpoint.port} -j REJECT
        ''
      )
      matching_endpoints}
  '';

  vpn_input_commands = namespace_name: namespace: let
    chain = vpn_chain_name namespace_name;
    inherit (namespace.backend.wireguard) interface_name;
  in ''
    ensure_netns_rule "$ns" "$iptables" filter ${chain} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ensure_netns_rule "$ns" "$ip6tables" filter ${chain} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ${concatMapStrings (
        port:
          concatMapStrings (protocol: ''
            ensure_netns_rule "$ns" "$iptables" filter ${chain} -i ${interface_name} -p ${protocol} --dport ${toString port.port} -j ACCEPT
            ensure_netns_rule "$ns" "$ip6tables" filter ${chain} -i ${interface_name} -p ${protocol} --dport ${toString port.port} -j ACCEPT
          '') (protocols_for port.protocol)
      )
      namespace.open_vpn_ports}
    ensure_netns_rule "$ns" "$iptables" filter ${chain} -i ${interface_name} -j REJECT
    ensure_netns_rule "$ns" "$ip6tables" filter ${chain} -i ${interface_name} -j REJECT
  '';

  accessible_route_commands = namespace: let
    host_v4 = plain_address namespace.addresses.host_v4;
    host_v6 =
      if namespace_has_ipv6 namespace
      then plain_address namespace.addresses.host_v6
      else null;
  in
    concatMapStrings (
      cidr: let
        family = family_for_address cidr;
        route = normalized_host_cidr family cidr;
      in
        if family == "ipv4"
        then ''
          netns_exec "$ip_cmd" route replace ${route} via ${host_v4} dev "$namespace_veth"
        ''
        else ''
          netns_exec "$ip_cmd" -6 route replace ${route} via ${host_v6} dev "$namespace_veth"
        ''
    )
    namespace.accessible_from;

  namespace_script = namespace_name: namespace: let
    host_veth_name = "nnh-${namespace_name}";
    namespace_veth_name = "nnp-${namespace_name}";
    has_ipv6 = namespace_has_ipv6 namespace;
  in
    pkgs.writeShellScript "network-namespace-${namespace_name}" ''
      set -euo pipefail

      ip_cmd=${pkgs.iproute2}/bin/ip
      iptables=${pkgs.iptables}/bin/iptables
      ip6tables=${pkgs.iptables}/bin/ip6tables
      wg_cmd=${pkgs.wireguard-tools}/bin/wg
      awk_cmd=${pkgs.gawk}/bin/awk
      mkdir_cmd=${pkgs.coreutils}/bin/mkdir
      mktemp_cmd=${pkgs.coreutils}/bin/mktemp
      rm_cmd=${pkgs.coreutils}/bin/rm

      ns=${escapeShellArg namespace_name}
      host_veth=${escapeShellArg host_veth_name}
      namespace_veth=${escapeShellArg namespace_veth_name}
      resolv_dir=${escapeShellArg "/etc/netns/${namespace_name}"}
      resolv_file=${escapeShellArg "/etc/netns/${namespace_name}/resolv.conf"}
      host_v4=${escapeShellArg (plain_address namespace.addresses.host_v4)}
      host_v4_cidr=${escapeShellArg (normalized_interface_cidr "ipv4" namespace.addresses.host_v4)}
      namespace_v4_cidr=${escapeShellArg (normalized_interface_cidr "ipv4" namespace.addresses.namespace_v4)}
      has_ipv6=${
        if has_ipv6
        then "1"
        else "0"
      }
      host_v6=${escapeShellArg (
        if has_ipv6
        then plain_address namespace.addresses.host_v6
        else ""
      )}
      host_v6_cidr=${escapeShellArg (
        if has_ipv6
        then normalized_interface_cidr "ipv6" namespace.addresses.host_v6
        else ""
      )}
      namespace_v6_cidr=${escapeShellArg (
        if has_ipv6
        then normalized_interface_cidr "ipv6" namespace.addresses.namespace_v6
        else ""
      )}
      strict_dns_enabled=${
        if namespace.dns.strict.enable
        then "1"
        else "0"
      }
      strict_dns_server_count=${toString (builtins.length namespace.dns.servers)}
      backend_type=${escapeShellArg namespace.backend.type}
      wg_config_file=${escapeShellArg (
        if namespace.backend.wireguard.config_file == null
        then ""
        else namespace.backend.wireguard.config_file
      )}
      wg_interface_name=${escapeShellArg namespace.backend.wireguard.interface_name}
      wg_host_interface_name=${escapeShellArg "wgn-${namespace_name}"}
      wg_runtime_conf=

      netns_exists() {
        "$ip_cmd" netns exec "$ns" true >/dev/null 2>&1
      }

      netns_exec() {
        "$ip_cmd" netns exec "$ns" "$@"
      }

      ensure_host_chain() {
        local tool=$1
        local table=$2
        local chain=$3

        "$tool" -t "$table" -N "$chain" 2>/dev/null || true
      }

      ensure_netns_chain() {
        local tool=$1
        local table=$2
        local chain=$3

        netns_exec "$tool" -t "$table" -N "$chain" 2>/dev/null || true
      }

      ensure_host_rule() {
        local tool=$1
        local table=$2
        local chain=$3
        shift 3

        if ! "$tool" -t "$table" -C "$chain" "$@" >/dev/null 2>&1; then
          "$tool" -t "$table" -A "$chain" "$@"
        fi
      }

      ensure_host_rule_first() {
        local tool=$1
        local table=$2
        local chain=$3
        shift 3

        if ! "$tool" -t "$table" -C "$chain" "$@" >/dev/null 2>&1; then
          "$tool" -t "$table" -I "$chain" 1 "$@"
        fi
      }

      ensure_netns_rule() {
        local netns=$1
        local tool=$2
        local table=$3
        local chain=$4
        shift 4

        if ! "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -C "$chain" "$@" >/dev/null 2>&1; then
          "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -A "$chain" "$@"
        fi
      }

      delete_host_rule() {
        local tool=$1
        local table=$2
        local chain=$3
        shift 3

        while "$tool" -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do
          "$tool" -t "$table" -D "$chain" "$@"
        done
      }

      delete_netns_rule() {
        local netns=$1
        local tool=$2
        local table=$3
        local chain=$4
        shift 4

        while "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do
          "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -D "$chain" "$@"
        done
      }

      remove_host_chain() {
        local tool=$1
        local table=$2
        local chain=$3

        "$tool" -t "$table" -F "$chain" 2>/dev/null || true
        "$tool" -t "$table" -X "$chain" 2>/dev/null || true
      }

      remove_netns_chain() {
        local netns=$1
        local tool=$2
        local table=$3
        local chain=$4

        "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -F "$chain" 2>/dev/null || true
        "$ip_cmd" netns exec "$netns" "$tool" -t "$table" -X "$chain" 2>/dev/null || true
      }

      run_teardown() {
        delete_host_rule "$iptables" nat PREROUTING -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
        delete_host_rule "$iptables" nat OUTPUT -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
        delete_host_rule "$iptables" filter FORWARD -i "$host_veth" -j ${forward_chain_name namespace_name}
        delete_host_rule "$iptables" filter FORWARD -o "$host_veth" -j ${forward_chain_name namespace_name}
        remove_host_chain "$iptables" nat ${nat_chain_name namespace_name}
        remove_host_chain "$iptables" filter ${forward_chain_name namespace_name}

        if [ "$has_ipv6" = 1 ]; then
          delete_host_rule "$ip6tables" nat PREROUTING -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
          delete_host_rule "$ip6tables" nat OUTPUT -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
          delete_host_rule "$ip6tables" filter FORWARD -i "$host_veth" -j ${forward_chain_name namespace_name}
          delete_host_rule "$ip6tables" filter FORWARD -o "$host_veth" -j ${forward_chain_name namespace_name}
          remove_host_chain "$ip6tables" nat ${nat_chain_name namespace_name}
          remove_host_chain "$ip6tables" filter ${forward_chain_name namespace_name}
        fi

        if netns_exists; then
          delete_netns_rule "$ns" "$iptables" filter OUTPUT -j ${dns_chain_name namespace_name}
          remove_netns_chain "$ns" "$iptables" filter ${dns_chain_name namespace_name}

          if [ "$has_ipv6" = 1 ]; then
            delete_netns_rule "$ns" "$ip6tables" filter OUTPUT -j ${dns_chain_name namespace_name}
            remove_netns_chain "$ns" "$ip6tables" filter ${dns_chain_name namespace_name}
          fi

          if [ "$backend_type" = wireguard ]; then
            delete_netns_rule "$ns" "$iptables" filter INPUT -i "$wg_interface_name" -j ${vpn_chain_name namespace_name}
            delete_netns_rule "$ns" "$ip6tables" filter INPUT -i "$wg_interface_name" -j ${vpn_chain_name namespace_name}
            remove_netns_chain "$ns" "$iptables" filter ${vpn_chain_name namespace_name}
            remove_netns_chain "$ns" "$ip6tables" filter ${vpn_chain_name namespace_name}
            netns_exec "$ip_cmd" link del "$wg_interface_name" 2>/dev/null || true
          fi

          netns_exec "$ip_cmd" link del "$namespace_veth" 2>/dev/null || true
          "$ip_cmd" netns del "$ns" 2>/dev/null || true
        fi

        if [ "$backend_type" = wireguard ]; then
          "$ip_cmd" link del "$wg_host_interface_name" 2>/dev/null || true
        fi
        "$ip_cmd" link del "$host_veth" 2>/dev/null || true
        "$rm_cmd" -rf "$resolv_dir"
      }

      cleanup_after_error() {
        if [ -n "''${wg_runtime_conf:-}" ]; then
          "$rm_cmd" -f "$wg_runtime_conf"
          wg_runtime_conf=
        fi
        run_teardown
      }

      run_setup() {
        trap cleanup_after_error ERR INT TERM

        run_teardown

        "$mkdir_cmd" -p /run/netns
        "$ip_cmd" netns add "$ns"
        netns_exec "$ip_cmd" link set lo up

        "$ip_cmd" link add "$host_veth" type veth peer name "$namespace_veth"
        "$ip_cmd" link set "$namespace_veth" netns "$ns"
        "$ip_cmd" addr replace "$host_v4_cidr" dev "$host_veth"
        "$ip_cmd" link set "$host_veth" up
        netns_exec "$ip_cmd" addr replace "$namespace_v4_cidr" dev "$namespace_veth"
        netns_exec "$ip_cmd" link set "$namespace_veth" up

        if [ "$has_ipv6" = 1 ]; then
          "$ip_cmd" -6 addr replace "$host_v6_cidr" dev "$host_veth"
          netns_exec "$ip_cmd" -6 addr replace "$namespace_v6_cidr" dev "$namespace_veth"
        fi

        ${accessible_route_commands namespace}

        if [ "$backend_type" = none ]; then
          netns_exec "$ip_cmd" route replace default via "$host_v4" dev "$namespace_veth"
          if [ "$has_ipv6" = 1 ]; then
            netns_exec "$ip_cmd" -6 route replace default via "$host_v6" dev "$namespace_veth"
          fi
        fi

        "$mkdir_cmd" -p "$resolv_dir"
        : > "$resolv_file"
        ${concatMapStrings (server: ''
          printf '%s\n' ${escapeShellArg "nameserver ${server}"} >> "$resolv_file"
        '')
        namespace.dns.servers}

        ensure_host_chain "$iptables" nat ${nat_chain_name namespace_name}
        ensure_host_chain "$iptables" filter ${forward_chain_name namespace_name}
        ensure_host_rule_first "$iptables" nat PREROUTING -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
        ensure_host_rule_first "$iptables" nat OUTPUT -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
        ensure_host_rule_first "$iptables" filter FORWARD -i "$host_veth" -j ${forward_chain_name namespace_name}
        ensure_host_rule_first "$iptables" filter FORWARD -o "$host_veth" -j ${forward_chain_name namespace_name}
        ensure_host_rule "$iptables" filter ${forward_chain_name namespace_name} -i "$host_veth" -j ACCEPT
        ensure_host_rule "$iptables" filter ${forward_chain_name namespace_name} -o "$host_veth" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        ${host_mapping_commands "ipv4" namespace_name namespace}
        ${host_forward_commands "ipv4" namespace_name namespace}

        if [ "$has_ipv6" = 1 ]; then
          ensure_host_chain "$ip6tables" nat ${nat_chain_name namespace_name}
          ensure_host_chain "$ip6tables" filter ${forward_chain_name namespace_name}
          ensure_host_rule_first "$ip6tables" nat PREROUTING -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
          ensure_host_rule_first "$ip6tables" nat OUTPUT -m addrtype --dst-type LOCAL -j ${nat_chain_name namespace_name}
          ensure_host_rule_first "$ip6tables" filter FORWARD -i "$host_veth" -j ${forward_chain_name namespace_name}
          ensure_host_rule_first "$ip6tables" filter FORWARD -o "$host_veth" -j ${forward_chain_name namespace_name}
          ensure_host_rule "$ip6tables" filter ${forward_chain_name namespace_name} -i "$host_veth" -j ACCEPT
          ensure_host_rule "$ip6tables" filter ${forward_chain_name namespace_name} -o "$host_veth" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
          ${host_mapping_commands "ipv6" namespace_name namespace}
          ${host_forward_commands "ipv6" namespace_name namespace}
        fi

        if [ "''${MY_NETWORK_NAMESPACES_FAIL_AFTER_CORE:-}" = "$ns" ]; then
          echo "Controlled core setup failure requested for namespace $ns" >&2
          exit 1
        fi

        if [ "$strict_dns_enabled" = 1 ]; then
          if [ "$strict_dns_server_count" -eq 0 ]; then
            echo "Strict DNS for namespace ${namespace_name} requires at least one DNS server." >&2
            exit 1
          fi

          ensure_netns_chain "$iptables" filter ${dns_chain_name namespace_name}
          ensure_netns_rule "$ns" "$iptables" filter OUTPUT -j ${dns_chain_name namespace_name}
          ${dns_allow_commands "ipv4" namespace_name namespace}
          ${dns_block_commands "ipv4" namespace_name namespace}

          ensure_netns_chain "$ip6tables" filter ${dns_chain_name namespace_name}
          ensure_netns_rule "$ns" "$ip6tables" filter OUTPUT -j ${dns_chain_name namespace_name}
          ${dns_allow_commands "ipv6" namespace_name namespace}
          ${dns_block_commands "ipv6" namespace_name namespace}
        fi

        if [ "$backend_type" = wireguard ]; then
          if [ -z "$wg_config_file" ] || [ ! -s "$wg_config_file" ]; then
            echo "WireGuard backend for namespace ${namespace_name} requires a non-empty config file." >&2
            exit 1
          fi

          wg_runtime_conf=$("$mktemp_cmd" "/run/$ns.wg.XXXXXX")
          "$awk_cmd" '
            /^[[:space:]]*(Address|DNS)[[:space:]]*=/ { next }
            { print }
          ' "$wg_config_file" > "$wg_runtime_conf"

          "$ip_cmd" link add "$wg_host_interface_name" type wireguard
          "$ip_cmd" link set "$wg_host_interface_name" netns "$ns"
          netns_exec "$ip_cmd" link set "$wg_host_interface_name" name "$wg_interface_name"
          netns_exec "$wg_cmd" setconf "$wg_interface_name" "$wg_runtime_conf"
          "$rm_cmd" -f "$wg_runtime_conf"
          wg_runtime_conf=

          while IFS= read -r address; do
            [ -n "$address" ] || continue
            netns_exec "$ip_cmd" address replace "$address" dev "$wg_interface_name"
          done < <(
            "$awk_cmd" -F '=' '
              /^[[:space:]]*Address[[:space:]]*=/ {
                value=$2
                gsub(/[[:space:]]/, "", value)
                gsub(/,/, "\n", value)
                print value
              }
            ' "$wg_config_file"
          )

          endpoint_host=$(
            "$awk_cmd" -F '=' '
              /^[[:space:]]*Endpoint[[:space:]]*=/ {
                value=$2
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                if (value ~ /^\[/) {
                  sub(/^\[/, "", value)
                  sub(/\]:[0-9]+$/, "", value)
                } else {
                  sub(/:[0-9]+$/, "", value)
                }
                print value
                exit
              }
            ' "$wg_config_file"
          )
          if [ -n "$endpoint_host" ]; then
            if printf '%s' "$endpoint_host" | "$awk_cmd" 'index($0, ":") { found=1 } END { exit(found ? 0 : 1) }'; then
              netns_exec "$ip_cmd" -6 route replace "$endpoint_host/128" via "$host_v6" dev "$namespace_veth"
            else
              netns_exec "$ip_cmd" route replace "$endpoint_host/32" via "$host_v4" dev "$namespace_veth"
            fi
          fi

          netns_exec "$ip_cmd" link set "$wg_interface_name" up
          netns_exec "$ip_cmd" route replace default dev "$wg_interface_name"

          if "$awk_cmd" -F '=' '
            /^[[:space:]]*Address[[:space:]]*=/ && $0 ~ /:/ { found=1 }
            END { exit(found ? 0 : 1) }
          ' "$wg_config_file"; then
            netns_exec "$ip_cmd" -6 route replace default dev "$wg_interface_name"
          fi

          ensure_netns_chain "$iptables" filter ${vpn_chain_name namespace_name}
          ensure_netns_chain "$ip6tables" filter ${vpn_chain_name namespace_name}
          ensure_netns_rule "$ns" "$iptables" filter INPUT -i "$wg_interface_name" -j ${vpn_chain_name namespace_name}
          ensure_netns_rule "$ns" "$ip6tables" filter INPUT -i "$wg_interface_name" -j ${vpn_chain_name namespace_name}
          ${vpn_input_commands namespace_name namespace}
        fi

        trap - ERR INT TERM
      }

      case "''${1:-setup}" in
        setup)
          run_setup
          ;;
        teardown)
          run_teardown
          ;;
        *)
          echo "Expected setup or teardown" >&2
          exit 2
          ;;
      esac
    '';

  namespace_service = namespace_name: namespace: let
    script = namespace_script namespace_name namespace;
  in
    nameValuePair namespace_name {
      description = "Network namespace ${namespace_name}";
      wantedBy = ["multi-user.target"];
      wants = ["firewall.service"];
      after = ["firewall.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${script} setup";
        ExecStopPost = "${script} teardown";
      };
    };

  service_attachment = namespace_name: service_name:
    nameValuePair service_name {
      requires = ["${namespace_name}.service"];
      bindsTo = ["${namespace_name}.service"];
      after = ["${namespace_name}.service"];
      serviceConfig = {
        NetworkNamespacePath = "/run/netns/${namespace_name}";
        BindReadOnlyPaths = [
          "/etc/netns/${namespace_name}/resolv.conf:/etc/resolv.conf:norbind"
        ];
        InaccessiblePaths = ["/run/nscd" "/run/resolvconf"];
      };
    };
in {
  options.my.network_namespaces = mkOption {
    type = t.attrsOf NetworkNamespace;
    default = {};
    description = "Internal service-level network namespace definitions.";
  };

  config = mkMerge [
    {
      assertions =
        [
          {
            assertion = builtins.length enabled_service_names == builtins.length (unique enabled_service_names);
            message = "my.network_namespaces services must attach to at most one namespace.";
          }
        ]
        ++ concatMap (
          namespace_name: let
            namespace = enabled_namespaces.${namespace_name};
            has_ipv6 = namespace_has_ipv6 namespace;
          in [
            {
              assertion = builtins.stringLength namespace_name <= 11;
              message = "my.network_namespaces.${namespace_name} must have a name of 11 characters or fewer so derived veth names fit kernel limits.";
            }
            {
              assertion = (!has_ipv6) || (namespace.addresses.host_v6 != null && namespace.addresses.namespace_v6 != null);
              message = "my.network_namespaces.${namespace_name} must set both addresses.host_v6 and addresses.namespace_v6 when IPv6 is enabled.";
            }
            {
              assertion = all (mapping: port_valid mapping.from && port_valid mapping.to) namespace.port_mappings;
              message = "my.network_namespaces.${namespace_name} port_mappings must use ports in the range 1-65535.";
            }
            {
              assertion = all (port: port_valid port.port) namespace.open_vpn_ports;
              message = "my.network_namespaces.${namespace_name} open_vpn_ports must use ports in the range 1-65535.";
            }
            {
              assertion = all (endpoint: endpoint.address != null && endpoint.port != null && port_valid endpoint.port) namespace.dns.strict.block_doh_endpoints;
              message = "my.network_namespaces.${namespace_name} dns.strict.block_doh_endpoints entries must set address and port in the range 1-65535.";
            }
            {
              assertion = namespace.backend.type != "wireguard" || (namespace.backend.wireguard.config_file != null && namespace.backend.wireguard.config_file != "");
              message = "my.network_namespaces.${namespace_name} with backend.type = \"wireguard\" must set backend.wireguard.config_file.";
            }
          ]
        )
        enabled_namespace_names;
    }
    (mkIf (enabled_namespace_names != []) {
      boot.kernel.sysctl =
        {
          "net.ipv4.ip_forward" = 1;
        }
        // optionalAttrs (any namespace_has_ipv6 enabled_namespace_values) {
          "net.ipv6.conf.all.forwarding" = 1;
        };

      systemd.services =
        listToAttrs (builtins.map (name: namespace_service name enabled_namespaces.${name}) enabled_namespace_names)
        // listToAttrs (
          concatMap (
            namespace_name:
              builtins.map (service_name: service_attachment namespace_name service_name) enabled_namespaces.${namespace_name}.services
          )
          enabled_namespace_names
        );
    })
    (mkIf (any (namespace: namespace.backend.type == "wireguard") enabled_namespace_values) {
      networking.firewall.checkReversePath = "loose";
    })
  ];
}
