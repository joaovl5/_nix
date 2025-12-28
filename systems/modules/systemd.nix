{...}: {
  # docker systemd bullshit
  # https://github.com/hercules-ci/arion/issues/122
  systemd.enableUnifiedCgroupHierarchy = false;
}
