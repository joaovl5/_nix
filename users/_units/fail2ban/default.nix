{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
in
  o.module "unit.fail2ban" (with o; {
    enable = toggle "Enable fail2ban" false;
    settings = {
      max_retry = opt "Allowed failures until host is banned" t.int 3;
      ban_time = opt "Standard ban time" t.str "30m";
      increment = {
        enable = toggle "Enable bantime increment for repeated bans" true;
        factor = opt "Increment factor exponent" t.str "2";
        multipliers = opt "Increment factor multipliers" t.str "1 2 4 8 16 32 64";
        random_time = opt "Max. time to mix randomly" t.str "50m";
        search_all_jails = toggle "Use entries from all jails to search past offenders" true;
      };
    };
    data_dir = optional "Directory for pihole state data" t.str {};
    endpoint = u.endpoint {
      port = 2049;
      target = "actual";
    };
  }) {} (opts: (o.when opts.enable {
    services = with opts.settings; {
      fail2ban = {
        enable = true;
        maxretry = max_retry;
        bantime = ban_time;
        bantime-increment = {
          inherit
            (increment)
            enable
            factor
            multipliers
            ;
          rndtime = increment.random_time;
          overalljails = increment.search_all_jails;
        };
        # TODO: ^1 - add more jails besides the default sshd one
      };
    };
  }))
