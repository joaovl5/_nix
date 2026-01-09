WIDTH=6

EMPTY_CHAR="░"
FILLED_CHAR="█"
# EMPTY_CHAR="░"
SHOW_PERCENTAGE=false

# Function to display usage
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <current> <total>

Display a progress bar showing current/total progress.

Arguments:
    current     Current value (numerator)
    total       Total value (denominator)

Options:
    -w WIDTH    Width of the progress bar in characters (default: 30)
    -f CHAR     Character for filled portion (default: ▮)
    -e CHAR     Character for empty portion (default: ▯)
    -p          Show percentage after progress bar (default: hidden)
    -h          Display this help message

Example:
    $0 45 100
    $0 -w 20 -f "█" -e "░" 75 100
    $0 -p 45 100
EOF
  exit 1
}

# Parse options
while getopts "w:f:e:ph" opt; do
  case $opt in
  w) WIDTH="$OPTARG" ;;
  f) FILLED_CHAR="$OPTARG" ;;
  e) EMPTY_CHAR="$OPTARG" ;;
  p) SHOW_PERCENTAGE=true ;;
  h) usage ;;
  *) usage ;;
  esac
done

# Shift to get positional arguments
shift $((OPTIND - 1))

# Check if we have exactly 2 arguments
if [ $# -ne 2 ]; then
  echo "Error: Expected 2 arguments (current and total)" >&2
  usage
fi

CURRENT="$1"
TOTAL="$2"

# Validate inputs are numbers
if ! [[ "$CURRENT" =~ ^-?[0-9]+\.?[0-9]*$ ]] || ! [[ "$TOTAL" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "Error: Arguments must be numeric" >&2
  exit 1
fi

# Validate total is not zero
if [ "$(echo "$TOTAL == 0" | bc -l 2>/dev/null || echo "1")" -eq 1 ]; then
  echo "Error: Total cannot be zero" >&2
  exit 1
fi

# Validate width is a positive integer
if ! [[ "$WIDTH" =~ ^[0-9]+$ ]] || [ "$WIDTH" -le 0 ]; then
  echo "Error: Width must be a positive integer" >&2
  exit 1
fi

# Calculate percentage and number of filled blocks
PERCENTAGE=$(echo "scale=2; ($CURRENT / $TOTAL) * 100" | bc -l)
FILLED_COUNT=$(echo "scale=0; ($CURRENT * $WIDTH) / $TOTAL" | bc -l)

# Handle edge cases (percentage > 100 or < 0)
if [ "$(echo "$FILLED_COUNT > $WIDTH" | bc -l)" -eq 1 ]; then
  FILLED_COUNT=$WIDTH
elif [ "$(echo "$FILLED_COUNT < 0" | bc -l)" -eq 1 ]; then
  FILLED_COUNT=0
fi

# Calculate empty blocks
EMPTY_COUNT=$((WIDTH - FILLED_COUNT))

# Build the progress bar
BAR="["
for ((i = 0; i < FILLED_COUNT; i++)); do
  BAR+="$FILLED_CHAR"
done
for ((i = 0; i < EMPTY_COUNT; i++)); do
  BAR+="$EMPTY_CHAR"
done
BAR+="]"

# Print the progress bar with optional percentage
if [ "$SHOW_PERCENTAGE" = true ]; then
  printf "%s %.1f%%\n" "$BAR" "$PERCENTAGE"
else
  printf "%s\n" "$BAR"
fi
