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

# 2. The temperature vs the feels like
plot_temperature_vs_feelslike() {
  echo "Generating 24-hour average temperature vs feels-like plot..."

  # Create a dat folder inside OUTPUT_DIR
  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract data from MySQL: group by hour and compute avg temperature and avg feels_like
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT 
      HOUR(timestamp) AS hour, 
      AVG(temperature) AS avg_temp, 
      AVG(feels_like) AS avg_feels
    FROM current_weather
    WHERE temperature IS NOT NULL AND feels_like IS NOT NULL
    GROUP BY hour
    ORDER BY hour;
  " > "$DAT_DIR/temp_vs_feels.dat"

  # Remove the header line
  tail -n +2 "$DAT_DIR/temp_vs_feels.dat" > "$DAT_DIR/temp_vs_feels_clean.dat"

  # Optional: Convert Fahrenheit to Celsius in the data file
  awk '{printf "%d %.2f %.2f\n", $1, ($2-32)*(5/9), ($3-32)*(5/9)}' "$DAT_DIR/temp_vs_feels_clean.dat" > "$DAT_DIR/temp_vs_feels_celsius.dat"

  # 2. Plot using gnuplot with timestamp in filename
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/temperature_vs_feelslike_$TIMESTAMP.png"

    set title "Average Temperature vs Feels-Like by Hour (24h)"
    set xlabel "Hour of Day"
    set ylabel "Temperature (°C)"
    
    set xtics 0,1,23
    set grid
    set key left top

    plot "$DAT_DIR/temp_vs_feels_celsius.dat" using 1:2 with lines lw 2 linecolor rgb "red" title "Temperature", \
         "$DAT_DIR/temp_vs_feels_celsius.dat" using 1:3 with lines lw 2 linecolor rgb "blue" title "Feels-Like"
EOF

  echo "Saved: $OUTPUT_DIR/temperature_vs_feelslike_$TIMESTAMP.png"
}

# 3. Plot humidity hourly
plot_humidity_hourly() {
  echo "Generating 24-hour average humidity plot..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract data from MySQL, group by hour
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT 
      HOUR(timestamp) AS hour, 
      AVG(humidity) AS avg_humidity
    FROM current_weather
    WHERE humidity IS NOT NULL
    GROUP BY hour
    ORDER BY hour;
  " > "$DAT_DIR/humidity_hourly.dat"

  # Remove header line
  tail -n +2 "$DAT_DIR/humidity_hourly.dat" > "$DAT_DIR/humidity_hourly_clean.dat"

  # 2. Plot using gnuplot
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/humidity_hourly_$TIMESTAMP.png"

    set title "Average Humidity by Hour (24h)"
    set xlabel "Hour of Day"
    set ylabel "Humidity (%)"

    set xtics 0,1,23
    set grid
    set key off

    plot "$DAT_DIR/humidity_hourly_clean.dat" using 1:2 with lines lw 2 linecolor rgb "blue"
EOF

  echo "Saved: $OUTPUT_DIR/humidity_hourly_$TIMESTAMP.png"
}

# 4. Wind speed vs direction
plot_wind_speed_direction() {
  echo "Generating wind speed by direction plot..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract average wind speed per direction
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT wind_direction, AVG(wind_speed) AS avg_speed
    FROM wind_data
    WHERE wind_speed IS NOT NULL AND wind_direction IS NOT NULL
    GROUP BY wind_direction
    ORDER BY FIELD(wind_direction,'N','NE','E','SE','S','SW','W','NW');
  " > "$DAT_DIR/wind_direction_avg.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/wind_direction_avg.dat" > "$DAT_DIR/wind_direction_avg_clean.dat"

  # 2. Plot using gnuplot
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/wind_direction_$TIMESTAMP.png"

    set title "Average Wind Speed by Direction"
    set xlabel "Wind Direction"
    set ylabel "Average Speed (mph)"

    set style data histograms
    set style fill solid 1.0 border -1
    set grid ytics

    plot "$DAT_DIR/wind_direction_avg_clean.dat" using 2:xtic(1) title ""
EOF

  echo "Saved: $OUTPUT_DIR/wind_direction_$TIMESTAMP.png"
}

# 5. Plot weather condition
plot_weather_condition() {
  echo "Generating weather condition count bar chart..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract counts per weather condition
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
  SELECT UPPER(TRIM(\`weather_condition\`)) AS cond, COUNT(*) AS count
  FROM current_weather
  GROUP BY cond
  ORDER BY count DESC;
" > "$DAT_DIR/weather_condition_counts.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/weather_condition_counts.dat" > "$DAT_DIR/weather_condition_counts_clean.dat"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 2. Plot using gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/weather_condition_counts_$TIMESTAMP.png"

    set title "Weather Condition Counts"
    set xlabel "Weather Condition"
    set ylabel "Count"

    set style data histograms
    set style fill solid 1.0 border -1
    set boxwidth 0.6

    set datafile separator "\t"      # Important: handle tab-delimited file
    set xtics rotate by -45

    plot "$DAT_DIR/weather_condition_counts_clean.dat" using 2:xtic(1) linecolor rgb "skyblue" title "Count"
EOF

  echo "Saved: $OUTPUT_DIR/weather_condition_counts_$TIMESTAMP.png"
}


# The main handle script argument
case "${1:-}" in
  temperature)
    plot_temperature_hourly
    ;;
  temp_vs_feels)
    plot_temperature_vs_feelslike
    ;;
  humidity)
    plot_humidity_hourly
    ;;
  wind)
    plot_wind_speed_direction
    ;;
  weather_condition)
    plot_weather_condition
    ;;
  *)
    echo "Usage: $0 {temperature|temp_vs_feels|humidity|wind}"
    exit 1
    ;;
esac
