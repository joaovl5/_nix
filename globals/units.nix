# Non-host specific settings go here for defining units
# They should not be enabled here, otherwise they'd be enabled for every host.
# These reference units declared at `../users/_units`
{
  my = {
    "unit.octodns" = {
    };

    "unit.pihole" = {
    };

    "unit.nixarr" = {
    };

    "unit.fxsync" = {
    };

    "unit.fail2ban" = {
      enable = true;
    };
  };
}
