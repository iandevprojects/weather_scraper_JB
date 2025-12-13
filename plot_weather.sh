#!/bin/bash

# Enable strict mode
set -Eeuo pipefail
IFS=$'\n\t'

trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

# Dabase configuration
DB_NAME="weather_db"
DB_USER="root"
DB_PASS=""
MYSQL_BIN="/c/xampp/mysql/bin/mysql.exe"

# Define output directory for plots
OUTPUT_DIR="./plots"
mkdir -p "$OUTPUT_DIR"

# Plotting functions

# 1. Plot average temperature for each hour of the day
plot_temperature_hourly() {
  echo "Generating 24-hour average temperature plot..."

  # Ensure the dat subfolder exists
  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # Timestamp for filenames
  FILE_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 1. Extract data from MySQL, group by hour and compute avg temp
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT 
      HOUR(timestamp) AS hour, 
      AVG(temperature) AS avg_temp
    FROM current_weather
    WHERE temperature IS NOT NULL
    GROUP BY hour
    ORDER BY hour;
  " > "$DAT_DIR/temperature_hourly_$FILE_TIMESTAMP.dat"

  # Remove the header line
  tail -n +2 "$DAT_DIR/temperature_hourly_$FILE_TIMESTAMP.dat" > "$DAT_DIR/temperature_hourly_clean_$FILE_TIMESTAMP.dat"

  # Convert Fahrenheit to Celsius in the data file
  awk '{printf "%d %.2f\n", $1, ($2-32)*(5/9)}' "$DAT_DIR/temperature_hourly_clean_$FILE_TIMESTAMP.dat" > "$DAT_DIR/temperature_hourly_celsius_$FILE_TIMESTAMP.dat"

  # 2. Plot using gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/temperature_hourly_$FILE_TIMESTAMP.png"

    set title "Average Temperature by Hour (24h)"
    set xlabel "Hour of Day"
    set ylabel "Temperature (°C)"

    set xtics 0,1,23
    set grid
    set key off

    plot "$DAT_DIR/temperature_hourly_celsius_$FILE_TIMESTAMP.dat" using 1:2 with lines lw 2 linecolor rgb "red"
EOF

  echo "Saved: $OUTPUT_DIR/temperature_hourly_$FILE_TIMESTAMP.png"
}

# The main handle script argument
case "${1:-}" in
  temperature)
    plot_temperature_hourly
    ;;
  *)
    echo "Usage: $0 temperature"
    exit 1
    ;;
esac
