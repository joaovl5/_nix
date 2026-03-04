{
  nx = _: {
    programs.mosh = {
      enable = true;
    };
  };

  hm = {inputs, ...}: let
    globals = import inputs.globals;
    inherit (globals) hosts;
    _mb = {
      hostname,
      ssh_user,
      port ? 22,
      forwardX11 ? false,
      forwardX11Trusted ? false,
      ...
    }: {
      user = ssh_user;
      inherit
        port
        hostname
        forwardX11
        forwardX11Trusted
        ;
    };

    matchblocks = builtins.mapAttrs (_name: _mb) hosts;
  in {
    programs.ssh = {
      matchBlocks = matchblocks;
    };
  };
}
