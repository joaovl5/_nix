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

  mbr = {size ? "1M"}: {
    inherit size;
    type = "EF02";
  };

  luks = {
    name ? "crypted",
    size ? "100%",
    passwordFile ? "/tmp/secret.key",
    allowDiscards ? true,
    additionalKeyFiles ? [],
  }: content: {
    inherit size;
    content = {
      inherit passwordFile;
      inherit additionalKeyFiles;
      inherit content;
      inherit name;
      type = "luks";
      # encrypt the root partition with luks2 and argon2id, will prompt for a passphrase, which will be used to unlock the partition.
      # cryptsetup luksFormat
      extraFormatArgs = [
        "--type luks2"
        "--cipher aes-xts-plain64"
        "--hash sha512"
        "--iter-time 5000"
        "--key-size 256"
        "--pbkdf argon2id"
        # use true random data from /dev/random, will block until enough entropy is available
        "--use-random"
      ];
      extraOpenArgs = [
        "--timeout 10"
      ];
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
