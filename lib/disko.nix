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
    passwordFile ? "/tmp/secret.key",
    allowDiscards ? true,
    additionalKeyFiles ? [],
    extraOpenArgs ? [],
  }: content: {
    inherit size;
    content = {
      inherit extraOpenArgs;
      inherit passwordFile;
      inherit additionalKeyFiles;
      inherit content;
      inherit name;
      type = "luks";
      settings = {
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
