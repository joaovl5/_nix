_: {
  # Kernel Params and Options
  boot.kernelParams = [
    # make it harder to influence slab cache layout
    "slab_nomerge"
    # enables zeroing of memory during allocation and free time
    # helps mitigate use-after-free vulnerabilaties
    "init_on_alloc=1"
    "init_on_free=1"
    # randomizes page allocator freelist, improving security by
    # making page allocations less predictable
    "page_alloc.shuffel=1"
    # enables Kernel Page Table Isolation, which mitigates Meltdown and
    # prevents some KASLR bypasses
    "pti=on"
    # randomizes the kernel stack offset on each syscall
    # making attacks that rely on a deterministic stack layout difficult
    "randomize_kstack_offset=on"
    # disables vsyscalls, they've been replaced with vDSO
    "vsyscall=none"
    # disables debugfs, which exposes sensitive info about the kernel
    "debugfs=off"
    # certain exploits cause an "oops", this makes the kernel panic if an "oops" occurs
    "oops=panic"
  ];
  boot.kernel.sysctl = {
    # disable privileged ports
    "net.ipv4.ip_unprivileged_port_start" = 0;

    # --- Kernel ---
    # randomize memory
    "kernel.randomize_va_space" = 2;
    # exec shield (stack protection)
    "kernel.exec-shield" = 1;
    # restrict usage of ptrace
    "kernel.yama.ptrace_scope" = 2;
    # prevent pointer leaks
    "kernel.kptr_restrict" = 2;
    # restrict kernel log to CAP_SYSLOG capability
    "kernel.dmesg_restrict" = 1;
    # kexec is used to boot another kernel during runtime and can be abused
    "kernel.kexec_load_disabled" = 1;

    # --- Filesystem ---
    "fs.suid_dumpable" = 0;
    # only permit symlinks to be followed when outside of a world-writable sticky directory
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    # prevent creating files in potentially attacker-controlled environments
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # --- Misc ---
    # ASLR memory protection (64-bit systems)
    "vm.mmap_rnd_bits" = 32;
    "vm.mmap_rnd_compat_bits" = 16;

    # --- Network ---
    # SYN flood attack protection (denial of service attack)
    "net.ipv4.tcp_syncookies" = 1;
    # protection against TIME-WAIT assassination
    "net.ipv4.tcp_rfc1337" = 1;
    # enable source validation of packets received (prevents IP spoofing)
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;

    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    # Protect against IP spoofing
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # prevent man-in-the-middle attacks
    "net.ipv4.icmp_echo_ignore_all" = 1;

    # ignore ICMP request, helps avoid Smurf attacks
    "net.ipv4.conf.all.forwarding" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
    # Reverse path filtering causes the kernel to do source validation of
    "net.ipv6.conf.all.forwarding" = 0;
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.default.accept_ra" = 0;

    ## TCP hardening
    # Prevent bogus ICMP errors from filling up logs.
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    ## TCP optimization
    # TCP Fast Open is a TCP extension that reduces network latency by packing
    # data in the sender’s initial TCP SYN. Setting 3 = enable TCP Fast Open for
    # both incoming and outgoing connections:
    "net.ipv4.tcp_fastopen" = 3;
    # Bufferbloat mitigations + slight improvement in throughput & latency
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "cake";
  };
}
