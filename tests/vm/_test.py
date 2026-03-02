# start_all()
#
# machine.wait_for_unit(
#     "multi-user.target",
# )
# machine.wait_for_unit(
#     "NetworkManager.service",
# )
#
# machine.succeed(
#     "id johtok",
# )
# machine.succeed(
#     "id -nG johtok | grep -qw wheel",
# )
# machine.succeed(
#     "systemctl is-enabled NetworkManager.service | grep -qx enabled",
# )
# machine.succeed(
#     "nix show-config | grep -E '^experimental-features = .*flakes' >/dev/null",
# )
# machine.succeed(
#     "nix show-config | grep -E '^experimental-features = .*nix-command' >/dev/null",
# )
