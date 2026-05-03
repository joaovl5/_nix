set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: yazi-zellij-live-cwd FISH_PID PATH" >&2
  exit 1
fi

fish_pid=$1
path=$2

if [[ ! $fish_pid =~ ^[0-9]+$ ]]; then
  echo "yazi-zellij-live-cwd: FISH_PID must be numeric" >&2
  exit 1
fi

payload="$fish_pid"$'\t'"$(printf '%s' "$path" | base64 -w0)"
fish -c "set -U __yazi_zellij_live_cwd \"\$argv[1]\"" -- "$payload"
