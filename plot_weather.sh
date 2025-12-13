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

    set yrange [0:*]   # start y-axis at 0

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

# 6. Plot Air Quality Over Time
plot_air_quality_over_time() {
  echo "Generating daily average Air Quality plot..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract daily average AQ value
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT DATE(timestamp) AS day, AVG(aq_value) AS avg_aq
    FROM atmospheric_data
    GROUP BY day
    ORDER BY day;
  " > "$DAT_DIR/air_quality_daily.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/air_quality_daily.dat" > "$DAT_DIR/air_quality_daily_clean.dat"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 2. Plot with gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/air_quality_over_time_$TIMESTAMP.png"

    set title "Daily Average Air Quality"
    set xlabel "Date"
    set ylabel "Average AQ Value"
    set grid

    set xdata time
    set timefmt "%Y-%m-%d"
    set format x "%m-%d"
    set xtics rotate by -45

    plot "$DAT_DIR/air_quality_daily_clean.dat" using 1:2 with linespoints pt 7 lc rgb "green" title "Avg AQ"
EOF

  echo "Saved: $OUTPUT_DIR/air_quality_over_time_$TIMESTAMP.png"
}


# 7. Plot Pressure Distribution
plot_pressure_distribution() {
  echo "Generating Pressure Distribution bar chart..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract counts per pressure level
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT pressure, COUNT(*) AS count
    FROM atmospheric_data
    GROUP BY pressure
    ORDER BY count DESC;
  " > "$DAT_DIR/pressure_counts.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/pressure_counts.dat" > "$DAT_DIR/pressure_counts_clean.dat"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 2. Plot with gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/pressure_distribution_$TIMESTAMP.png"

    set title "Pressure Distribution"
    set xlabel "Pressure"
    set ylabel "Count"

    set style data histograms
    set style fill solid 1.0 border -1
    set boxwidth 0.6

    set datafile separator "\t"
    set xtics rotate by -45

    set yrange [0:*]           # <-- force y-axis to start at 0

    plot "$DAT_DIR/pressure_counts_clean.dat" using 2:xtic(1) linecolor rgb "orange" title "Count"
EOF

  echo "Saved: $OUTPUT_DIR/pressure_distribution_$TIMESTAMP.png"
}

# 8. Plot UV value over time
plot_uv_over_time() {
  echo "Generating UV Index Over Time plot..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract average UV value per date
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT DATE(timestamp) AS day, ROUND(AVG(uv_value),1) AS avg_uv
    FROM atmospheric_data
    GROUP BY day
    ORDER BY day;
  " > "$DAT_DIR/uv_over_time.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/uv_over_time.dat" > "$DAT_DIR/uv_over_time_clean.dat"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 2. Plot with gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/uv_over_time_$TIMESTAMP.png"

    set title "Average UV Index Over Time"
    set xlabel "Date"
    set ylabel "UV Value"
    set grid

    set xdata time
    set timefmt "%Y-%m-%d"
    set format x "%m-%d"
    set xtics rotate by -45

    plot "$DAT_DIR/uv_over_time_clean.dat" using 1:2 with linespoints pt 7 lc rgb "purple" title "UV Value"
EOF

  echo "Saved: $OUTPUT_DIR/uv_over_time_$TIMESTAMP.png"
}

# 9. Plot temperature vs humidity
plot_temperature_vs_humidity() {
  echo "Generating Temperature vs Humidity scatter plot (°C)..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract temperature (converted to °C) and humidity
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT ROUND((temperature - 32) * 5 / 9, 1) AS temp_c, humidity
    FROM current_weather
    ORDER BY timestamp;
  " > "$DAT_DIR/temp_vs_humidity.dat"

  # Remove header
  tail -n +2 "$DAT_DIR/temp_vs_humidity.dat" > "$DAT_DIR/temp_vs_humidity_clean.dat"

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 2. Plot with gnuplot
  gnuplot <<EOF
    set terminal png size 1200,600
    set output "$OUTPUT_DIR/temp_vs_humidity_$TIMESTAMP.png"

    set title "Temperature vs Humidity"
    set xlabel "Temperature (°C)"
    set ylabel "Humidity (%)"
    set grid

    plot "$DAT_DIR/temp_vs_humidity_clean.dat" using 1:2 with points pt 7 lc rgb "blue" title "Humidity"
EOF

  echo "Saved: $OUTPUT_DIR/temp_vs_humidity_$TIMESTAMP.png"
}

# 10. Plot sun times
plot_sunrise_sunset() {
  echo "Generating daily sunrise and sunset plots..."

  DAT_DIR="$OUTPUT_DIR/dat"
  mkdir -p "$DAT_DIR"

  # 1. Extract one row per date (min timestamp)
  $MYSQL_BIN -u "$DB_USER" --password="$DB_PASS" -D "$DB_NAME" -e "
    SELECT DATE(timestamp) AS day,
       MIN(NULLIF(sunrise, '00:00:00')) AS sunrise,
       MIN(NULLIF(sunset, '00:00:00')) AS sunset
  FROM sun_times
  GROUP BY day
  ORDER BY day;
  " > "$DAT_DIR/sun_times_daily.dat"

  tail -n +2 "$DAT_DIR/sun_times_daily.dat" > "$DAT_DIR/sun_times_daily_clean.dat"

  # 2. Convert times to seconds since midnight
  awk '{
    day=$1

    # Sunrise (AM assumed)
    split($2, t, ":")
    sunrise=t[1]*3600 + t[2]*60

    # Sunset (convert PM if needed)
    split($3, t, ":")
    hr=t[1]+0; min=t[2]+0
    if(hr < 12) hr += 12   # adjust PM
    sunset=hr*3600 + min*60

    print day, sunrise, sunset
  }' "$DAT_DIR/sun_times_daily_clean.dat" > "$DAT_DIR/sun_times_seconds.dat"

  # 3. Generate y-axis mapping (date to row number)
  awk '{print NR-1, $1}' "$DAT_DIR/sun_times_seconds.dat" > "$DAT_DIR/sun_times_ytics.dat"
  YTICS=$(awk '{printf "\"%s\" %d, ", $2, $1}' "$DAT_DIR/sun_times_ytics.dat")
  YTICS=${YTICS%, }  # remove trailing comma

  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # 4. Sunrise plot
  gnuplot <<EOF
set terminal png size 1200,600
set output "$OUTPUT_DIR/sunrise_$TIMESTAMP.png"

set title "Sunrise Times by Day"
set ylabel "Time of Day"
set xlabel "Date"
set grid

set ydata time
set timefmt "%s"
set format y "%H:%M"
set xtics ($YTICS)

plot "$DAT_DIR/sun_times_seconds.dat" using 0:2 with linespoints pt 7 lc rgb "orange" title "Sunrise"
EOF

  # 5. Sunset plot
  gnuplot <<EOF
set terminal png size 1200,600
set output "$OUTPUT_DIR/sunset_$TIMESTAMP.png"

set title "Sunset Times by Day"
set ylabel "Time of Day"
set xlabel "Date"
set grid

set ydata time
set timefmt "%s"
set format y "%H:%M"
set xtics ($YTICS)

plot "$DAT_DIR/sun_times_seconds.dat" using 0:3 with linespoints pt 7 lc rgb "blue" title "Sunset"
EOF

  echo "Saved: $OUTPUT_DIR/sunrise_$TIMESTAMP.png"
  echo "Saved: $OUTPUT_DIR/sunset_$TIMESTAMP.png"
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
  pressure)
    plot_pressure_distribution
    ;;
  air_quality)
    plot_air_quality_over_time
    ;;
  uv_value)
    plot_uv_over_time
    ;;
  temp_vs_humidity)
    plot_temperature_vs_humidity
    ;;
  sun_times)
    plot_sunrise_sunset
    ;;
  *)
    echo "Usage: $0 {temperature|temp_vs_feels|humidity|wind}"
    exit 1
    ;;
esac
