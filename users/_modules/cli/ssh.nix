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

    matchblocks_list =
      map (host: {
        name = host.host;
        value = _mb host;
      })
      hosts;

    matchblocks = builtins.listToAttrs matchblocks_list;
  in {
    programs.ssh = {
      matchBlocks = matchblocks;
    };
  };
}
