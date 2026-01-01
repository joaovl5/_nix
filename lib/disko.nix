{
  efi = {
    size ? "1G",
    mountpoint ? "/boot",
  }: {
    inherit size;
    type = "EF00";
    content = {
      inherit mountpoint;
      type = "filesystem";
      format = "vfat";
      mountOptions = ["umask=0077"];
    };
  };

  luks = {
    name ? "crypted",
    size ? "100%",
    keyFile ? "/tmp/secret.key",
    allowDiscards ? true,
    additionalKeyFiles ? [],
    extraOpenArgs ? [],
  }: content: {
    inherit size;
    content = {
      inherit extraOpenArgs;
      inherit additionalKeyFiles;
      inherit content;
      inherit name;
      type = "luks";
      settings = {
        # if you want to use the key for interactive login be sure there is no trailing newline
        # for example use `echo -n "password" > /tmp/secret.key`
        inherit keyFile;
        inherit allowDiscards;
      };
    };
  };

  btrfs.swap = {
    sz ? "10G",
    mp ? "/.swapvol",
  }: {
    mountpoint = mp;
    swap.swapfile.size = sz;
  };

  btrfs.subvolume = {
    mp,
    opts ? [
      "compress=zstd:1"
      "noatime"
    ],
    extraOpts ? [],
  }: {
    mountpoint = mp;
    mountOptions = opts ++ extraOpts;
  };
}
