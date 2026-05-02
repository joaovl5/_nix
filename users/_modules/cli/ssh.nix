{
  nx = _: {
    programs.mosh = {
      enable = true;
    };
  };

  hm = {globals, ...}: let
    inherit (globals) hosts;
    _mb = {
      hostname,
      ssh_user,
      ssh_port ? 22,
      forwardX11 ? false,
      forwardX11Trusted ? false,
      ...
    }: {
      user = ssh_user;
      inherit
        hostname
        forwardX11
        forwardX11Trusted
        ;
      port = ssh_port;
    };

    matchblocks = builtins.mapAttrs (_name: _mb) hosts;
  in {
    programs.ssh = {
      matchBlocks = matchblocks;
    };
  };
}
