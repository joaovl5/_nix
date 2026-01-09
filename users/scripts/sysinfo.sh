PROGRESS_SCRIPT="./progress.sh"
SHOW_CPU=false
SHOW_RAM=false
SHOW_DISK=false
SHOW_VOL=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Display system information as progress bars.

Options:
    -c              Show CPU usage
    -r              Show RAM usage
    -d              Show disk usage
    -v              Show volume level
    -a              Show all metrics
    -p <path>       Path to progress script (default: ./progress.sh)
    -h              Display this help message

Examples:
    $0 -c
    $0 -c -r
    $0 -a
    $0 -a -p /usr/local/bin/progress.sh

Note: Without any options, nothing will be displayed.
EOF
  exit 1
}

# Parse options
while getopts "crdvap:h" opt; do
  case $opt in
    c) SHOW_CPU=true ;;
    r) SHOW_RAM=true ;;
    d) SHOW_DISK=true ;;
    v) SHOW_VOL=true ;;
    a)
      SHOW_CPU=true
      SHOW_RAM=true
      SHOW_DISK=true
      SHOW_VOL=true
      ;;
    p) PROGRESS_SCRIPT="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Check if progress bar script exists
if [ ! -f "$PROGRESS_SCRIPT" ]; then
  echo "Error: Progress bar script not found at $PROGRESS_SCRIPT" >&2
  exit 1
fi

# Make sure it's executable
if [ ! -x "$PROGRESS_SCRIPT" ]; then
  chmod +x "$PROGRESS_SCRIPT" 2>/dev/null || {
    echo "Error: Cannot execute $PROGRESS_SCRIPT" >&2
    exit 1
  }
fi

# If no options selected, show usage
if [ "$SHOW_CPU" = false ] && [ "$SHOW_RAM" = false ] && [ "$SHOW_DISK" = false ] && [ "$SHOW_VOL" = false ]; then
  usage
fi

# CPU Usage
if [ "$SHOW_CPU" = true ]; then
  CPU_IDLE=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -n1 | awk '{print $8}' | cut -d'%' -f1)
  CPU_USAGE=$(echo "scale=2; 100 - $CPU_IDLE" | bc -l)
  CPU_USAGE_INT=$(echo "scale=0; $CPU_USAGE / 1" | bc -l)
  "$PROGRESS_SCRIPT" "$CPU_USAGE_INT" 100
fi

# RAM Usage
if [ "$SHOW_RAM" = true ]; then
  RAM_INFO=$(free | grep Mem)
  RAM_TOTAL=$(echo $RAM_INFO | awk '{print $2}')
  RAM_USED=$(echo $RAM_INFO | awk '{print $3}')
  "$PROGRESS_SCRIPT" "$RAM_USED" "$RAM_TOTAL"
fi

# Disk Usage
if [ "$SHOW_DISK" = true ]; then
  DISK_INFO=$(df -h / | tail -n1)
  DISK_USED=$(echo $DISK_INFO | awk '{print $3}' | sed 's/G//;s/M/\/1024/;s/K/\/1024\/1024/' | bc -l 2>/dev/null | cut -d'.' -f1)
  DISK_TOTAL=$(echo $DISK_INFO | awk '{print $2}' | sed 's/G//;s/M/\/1024/;s/K/\/1024\/1024/' | bc -l 2>/dev/null | cut -d'.' -f1)

  if [ -z "$DISK_USED" ] || [ -z "$DISK_TOTAL" ]; then
    DISK_PERCENT=$(echo $DISK_INFO | awk '{print $5}' | sed 's/%//')
    "$PROGRESS_SCRIPT" "$DISK_PERCENT" 100
  else
    "$PROGRESS_SCRIPT" "$DISK_USED" "$DISK_TOTAL"
  fi
fi

# Volume Usage
if [ "$SHOW_VOL" = true ]; then
  if command -v wpctl &>/dev/null; then
    VOL_OUTPUT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$VOL_OUTPUT" ]; then
      VOL_DECIMAL=$(echo "$VOL_OUTPUT" | awk '{print $2}')
      VOL_PERCENT=$(echo "scale=0; $VOL_DECIMAL * 100 / 1" | bc -l)
      "$PROGRESS_SCRIPT" "$VOL_PERCENT" 100
    else
      echo "[Volume unavailable]"
    fi
  else
    echo "[wpctl not installed]"
  fi
fi

