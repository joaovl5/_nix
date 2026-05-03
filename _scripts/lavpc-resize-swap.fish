#!/run/current-system/sw/bin/env fish

set -l default_swap_path /.swapvol/swapfile
set -l default_temp_path /.swapvol/temp-swapfile
set -l default_temp_size 16G

function usage
    set -l script_name (status filename)
    printf '%s\n' \
        "Usage: $script_name NEW_SIZE [options]" \
        "" \
        "Resize lavpc's Btrfs swapfile using a temporary swapfile." \
        "" \
        "Arguments:" \
        "  NEW_SIZE              New size for /.swapvol/swapfile, e.g. 64G" \
        "" \
        "Options:" \
        "  --temp-size SIZE      Temporary swap size (default: 16G)" \
        "  --swap-path PATH      Swapfile to replace (default: /.swapvol/swapfile)" \
        "  --temp-path PATH      Temporary swapfile path (default: /.swapvol/temp-swapfile)" \
        "  -y, --yes             Do not ask for confirmation" \
        "  --dry-run             Print the plan after preflight checks; do not require root" \
        "  -h, --help            Show this help" \
        "" \
        "Notes:" \
        "  Sizes must be integer K/M/G/T values, matching btrfs filesystem mkswapfile." \
        "  After a live resize, update hardware/_disko/lavpc_v2.nix for future installs."
end

function die
    echo "Error: $argv" >&2
    exit 1
end

function warn
    echo "Warning: $argv" >&2
end

function require_command --argument-names cmd
    command -q -- "$cmd"; or die "Missing required command: $cmd"
end

function size_to_bytes --argument-names raw_size
    set -l normalized (string upper -- "$raw_size")
    set -l match (string match -r '^([0-9]+)([KMGTP])$' -- "$normalized")

    if test (count $match) -ne 3
        return 1
    end

    set -l number $match[2]
    set -l unit $match[3]
    set -l multiplier

    switch $unit
        case K
            set multiplier 1024
        case M
            set multiplier 1048576
        case G
            set multiplier 1073741824
        case T
            set multiplier 1099511627776
        case P
            set multiplier 1125899906842624
    end

    math --scale=0 "$number * $multiplier"
end

function active_swap_row --argument-names wanted_path
    set -l wanted_real (readlink -f -- "$wanted_path")

    for row in (swapon --show=NAME,SIZE,USED --noheadings --raw --bytes)
        set -l cols (string split -n ' ' -- $row)
        if test (count $cols) -lt 3
            continue
        end

        set -l row_real (readlink -f -- "$cols[1]")
        if test "$row_real" = "$wanted_real"
            echo $row
            return 0
        end
    end

    return 1
end

function is_active_swap --argument-names wanted_path
    active_swap_row "$wanted_path" >/dev/null
end

function cleanup_temp_swap --argument-names temp_path
    set -l failed 0

    if is_active_swap "$temp_path"
        swapoff "$temp_path"; or set failed 1
    end

    if test -e "$temp_path"
        rm -f -- "$temp_path"; or set failed 1
    end

    return $failed
end

function restore_old_swap --argument-names swap_path restore_size
    warn "Attempting to restore the original swapfile at $swap_path with size $restore_size."
    rm -f -- "$swap_path"; or return 1
    btrfs filesystem mkswapfile --size "$restore_size" "$swap_path"; or return 1
    swapon "$swap_path"; or return 1
end

function print_plan --argument-names swap_path temp_path new_size temp_size active_size active_used available_bytes
    printf '%s\n' \
        "Host:               "(hostname) \
        "Swapfile:           $swap_path" \
        "Current swap size:  $active_size bytes" \
        "Current swap used:  $active_used bytes" \
        "Available space:    $available_bytes bytes" \
        "New swap size:      $new_size" \
        "Temporary swapfile: $temp_path" \
        "Temporary size:     $temp_size" \
        "" \
        "Planned commands:" \
        "  btrfs filesystem mkswapfile --size $temp_size $temp_path" \
        "  swapon $temp_path" \
        "  swapoff $swap_path" \
        "  rm -f -- $swap_path" \
        "  btrfs filesystem mkswapfile --size $new_size $swap_path" \
        "  swapon $swap_path" \
        "  swapoff $temp_path" \
        "  rm -f -- $temp_path"
end

set -l swap_path $default_swap_path
set -l temp_path $default_temp_path
set -l temp_size $default_temp_size
set -l assume_yes 0
set -l dry_run 0
set -l new_size

while test (count $argv) -gt 0
    set -l arg $argv[1]
    set -e argv[1]

    switch $arg
        case -h --help
            usage
            exit 0
        case -y --yes
            set assume_yes 1
        case --dry-run
            set dry_run 1
        case --swap-path
            test (count $argv) -gt 0; or die "--swap-path requires a value"
            set swap_path $argv[1]
            set -e argv[1]
        case '--swap-path=*'
            set swap_path (string replace -- '--swap-path=' '' "$arg")
        case --temp-path
            test (count $argv) -gt 0; or die "--temp-path requires a value"
            set temp_path $argv[1]
            set -e argv[1]
        case '--temp-path=*'
            set temp_path (string replace -- '--temp-path=' '' "$arg")
        case --temp-size
            test (count $argv) -gt 0; or die "--temp-size requires a value"
            set temp_size $argv[1]
            set -e argv[1]
        case '--temp-size=*'
            set temp_size (string replace -- '--temp-size=' '' "$arg")
        case '-*'
            die "Unknown option: $arg"
        case '*'
            if set -q new_size[1]
                die "Unexpected extra argument: $arg"
            end
            set new_size $arg
    end
end

set -q new_size[1]; or begin
    usage >&2
    exit 2
end

for cmd in btrfs df findmnt hostname id readlink rm stat swapon swapoff
    require_command "$cmd"
end

set -l host (hostname)
test "$host" = lavpc; or die "This script is lavpc-specific; current host is '$host'."

string match -q -r '^/' -- "$swap_path"; or die "--swap-path must be absolute: $swap_path"
string match -q -r '^/' -- "$temp_path"; or die "--temp-path must be absolute: $temp_path"
test "$swap_path" != "$temp_path"; or die "--swap-path and --temp-path must be different"

test -f "$swap_path"; or die "Swapfile does not exist: $swap_path"
test -e "$temp_path"; and die "Temporary path already exists: $temp_path"

set -l new_size_bytes (size_to_bytes "$new_size")
test $status -eq 0; or die "Invalid NEW_SIZE '$new_size'. Use an integer K/M/G/T value, e.g. 64G."

set -l temp_size_bytes (size_to_bytes "$temp_size")
test $status -eq 0; or die "Invalid --temp-size '$temp_size'. Use an integer K/M/G/T value, e.g. 16G."

set -l swap_dir (path dirname -- "$swap_path")
set -l temp_dir (path dirname -- "$temp_path")
test "$swap_dir" = "$temp_dir"; or die "Temporary swapfile must be in the same Btrfs directory as the target swapfile."

set -l fs_type (findmnt -no FSTYPE --target "$swap_dir")
test "$fs_type" = btrfs; or die "$swap_dir is on '$fs_type', not btrfs"

set -l active_row (active_swap_row "$swap_path")
test $status -eq 0; or die "$swap_path is not currently active swap"

set -l active_cols (string split -n ' ' -- $active_row)
set -l active_size_bytes $active_cols[2]
set -l active_used_bytes $active_cols[3]

if test "$temp_size_bytes" -lt "$active_used_bytes"
    die "Temporary size $temp_size is smaller than current used swap ($active_used_bytes bytes). Re-run with a larger --temp-size."
end

set -l old_file_bytes (stat -c %s -- "$swap_path")
set -l restore_size_mib (math --scale=0 "ceil($old_file_bytes / 1048576)")
set -l restore_size "$restore_size_mib"M

set -l df_lines (df --output=avail -B1 -- "$swap_dir")
set -l available_bytes (string trim -- $df_lines[-1])

if test "$available_bytes" -lt "$temp_size_bytes"
    die "Not enough free space in $swap_dir for temporary swapfile: need $temp_size_bytes bytes, have $available_bytes bytes."
end

set -l needed_after_old_removed (math --scale=0 "$temp_size_bytes + $new_size_bytes")
set -l available_after_old_removed (math --scale=0 "$available_bytes + $old_file_bytes")

if test "$available_after_old_removed" -lt "$needed_after_old_removed"
    die "Not enough temporary free space for temp + new swapfiles: need $needed_after_old_removed bytes after removing old swap, have $available_after_old_removed bytes."
end

print_plan "$swap_path" "$temp_path" "$new_size" "$temp_size" "$active_size_bytes" "$active_used_bytes" "$available_bytes"

if test "$dry_run" -eq 1
    exit 0
end

if test (id -u) -ne 0
    die "Run as root, for example: sudo fish "(status filename)" $new_size"
end

if test "$assume_yes" -ne 1
    read -l -P "Continue with live swap resize? [y/N] " answer
    switch (string lower -- "$answer")
        case y yes
        case '*'
            die Aborted
    end
end

echo "Creating temporary swapfile..."
btrfs filesystem mkswapfile --size "$temp_size" "$temp_path"; or die "Failed to create temporary swapfile"

if not swapon "$temp_path"
    rm -f -- "$temp_path"
    die "Failed to enable temporary swapfile"
end

echo "Disabling current swapfile..."
if not swapoff "$swap_path"
    cleanup_temp_swap "$temp_path"
    die "Failed to disable current swapfile; temporary swapfile was removed"
end

echo "Replacing swapfile..."
if not rm -f -- "$swap_path"
    swapon "$swap_path"; or warn "Could not re-enable original swapfile after rm failure"
    cleanup_temp_swap "$temp_path"
    die "Failed to remove old swapfile"
end

if not btrfs filesystem mkswapfile --size "$new_size" "$swap_path"
    warn "Failed to create new swapfile. Trying to restore the original swapfile."
    if restore_old_swap "$swap_path" "$restore_size"
        cleanup_temp_swap "$temp_path"
        die "Resize failed; original swapfile was restored"
    end

    warn "CRITICAL: original swapfile could not be restored; temporary swap remains active if possible. Check 'swapon --show'."
    exit 1
end

if not swapon "$swap_path"
    warn "Failed to enable new swapfile. Trying to restore the original swapfile."
    rm -f -- "$swap_path"

    if restore_old_swap "$swap_path" "$restore_size"
        cleanup_temp_swap "$temp_path"
        die "Resize failed; original swapfile was restored"
    end

    warn "CRITICAL: original swapfile could not be restored; temporary swap remains active if possible. Check 'swapon --show'."
    exit 1
end

echo "Removing temporary swapfile..."
if not cleanup_temp_swap "$temp_path"
    warn "New swapfile is active, but temporary swap cleanup failed. Check 'swapon --show' and remove $temp_path manually."
    exit 1
end

echo "Swap resize finished. Current swap devices:"
swapon --show

echo "Reminder: update hardware/_disko/lavpc_v2.nix to sz = \"$new_size\" for future installs."
