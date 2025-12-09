#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

URL="https://weather.yahoo.com/my/johor/johor-baharu"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "========== WEATHER SCRAPER RUN AT $TIMESTAMP =========="

echo ""
echo "Fetching page..."
PAGE=$(curl -s "$URL")

# 1. Track current weather

temperature=$(echo "$PAGE" \
  | grep -oP '<p class="text-primary[^>]*>\K[0-9]+' \
  | head -1)
condition=$(echo "$PAGE" \
  | grep -oP '<p class="text-primary font-caption2[^>]*>\K[^<]+' \
  | head -1)
feels_like=$(echo "$PAGE" \
  | grep -oP 'RealFeel.? *\K[0-9]+' \
  | head -1)
humidity=$(echo "$PAGE" \
  | grep -oP 'Very humid · \K[0-9]+' \
  | head -1)

echo "--- CURRENT WEATHER (current_weather table) ---"
echo "timestamp:      $TIMESTAMP"
echo "temperature:    $temperature"
echo "condition:      $condition"
echo "feels_like:     $feels_like"
echo "humidity:       $humidity"
echo ""

INSERT_CURRENT="INSERT INTO current_weather (timestamp, temperature, weather_condition, feels_like, humidity)
VALUES ('$TIMESTAMP', $temperature, '$condition', $feels_like, $humidity);"

# 2. Track wind data

wind_text=$(echo "$PAGE" \
  | grep -oP '<p class="text-primary font-label2[^>]*>\K[^<]+' \
  | grep -m1 '[0-9]')
wind_text=$(echo "$wind_text" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
wind_speed=$(echo "$wind_text" | grep -oP '^[0-9]+')
wind_dir=$(echo "$wind_text" | grep -oP '[A-Z]+$')

echo "--- WIND DATA (wind_data table) ---"
echo "wind_speed:     $wind_speed"
echo "wind_direction: $wind_dir"
echo ""

INSERT_WIND="INSERT INTO wind_data (timestamp, wind_speed, wind_direction)
VALUES ('$TIMESTAMP', $wind_speed, '$wind_dir');"

# 3. Atmospheric data

visibility=$(echo "$PAGE" \
  | grep -oP '<p class="font-label2 font-size-label2 font-weight-label2 leading-label2 case-label2 text-center justify-center text-blue-12">\K[^<]+' \
  | head -1)
pressure=$(echo "$PAGE" \
  | grep -A3 'Pressure' \
  | grep -oP '<p[^>]*text-blue-12[^>]*>\K[^<]+')
aq_text=$(echo "$PAGE" \
  | grep -oP '<p class="font-label2 font-size-label2 font-weight-label2 leading-label2 case-label2 text-center justify-center text-green-12">\K[^<]+' \
  | head -1)
aq_label=$(echo "$aq_text" | awk -F '·' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
aq_value=$(echo "$aq_text" | grep -oP '[0-9]+')
uv_text=$(echo "$PAGE" \
  | grep -oP '<p class="font-label2 font-size-label2 font-weight-label2 leading-label2 case-label2 text-center justify-center text-green-12">\K[^<]+' \
  | head -1)
uv_label=$(echo "$uv_text" | awk -F '·' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
uv_value=$(echo "$uv_text" | grep -oP '[0-9]+')

echo "--- ATMOSPHERIC DATA (atmospheric_data table) ---"
echo "visibility:     $visibility"
echo "pressure:       $pressure"
echo "aq_label:       $aq_label"
echo "aq_value:       $aq_value"
echo "uv_label:       $uv_label"
echo "uv_value:       $uv_value"
echo ""

INSERT_ATMOS="INSERT INTO atmospheric_data (timestamp, visibility, pressure, aq_label, aq_value, uv_label, uv_value)
VALUES ('$TIMESTAMP', '$visibility', '$pressure', '$aq_label', $aq_value, '$uv_label', $uv_value);"

# 4. Track sun times

sun_times=$(echo "$PAGE" \
  | grep -oP '<p class="text-secondary font-body1 font-size-body1 font-weight-body1 leading-body1 case-body1">\K[^<]+' )

sunrise=$(echo "$sun_times" | sed -n '1p')
sunset=$(echo "$sun_times" | sed -n '2p')

echo "--- SUN TIMES (sun_times table) ---"
echo "sunrise:        $sunrise"
echo "sunset:         $sunset"
echo ""

INSERT_SUN="INSERT INTO sun_times (timestamp, sunrise, sunset)
VALUES ('$TIMESTAMP', '$sunrise', '$sunset');"


# MySQL credentials
DB_USER="root"
DB_PASS=""
DB_NAME="weather_db"

echo "Testing MySQL connection..."

# Could not access path and thus used the direct path
MYSQL_BIN="/c/xampp/mysql/bin/mysql.exe"

# Used --password= as the password is set to empty
# If password is empty
if [ -z "$DB_PASS" ]; then
    $MYSQL_BIN -u $DB_USER --password= -D $DB_NAME -e "$INSERT_CURRENT"
    $MYSQL_BIN -u $DB_USER --password= -D $DB_NAME -e "$INSERT_WIND"
    $MYSQL_BIN -u $DB_USER --password= -D $DB_NAME -e "$INSERT_ATMOS"
    $MYSQL_BIN -u $DB_USER --password= -D $DB_NAME -e "$INSERT_SUN"
else
    $MYSQL_BIN -u $DB_USER -p"$DB_PASS" -D $DB_NAME -e "$INSERT_CURRENT"
    $MYSQL_BIN -u $DB_USER -p"$DB_PASS" -D $DB_NAME -e "$INSERT_WIND"
    $MYSQL_BIN -u $DB_USER -p"$DB_PASS" -D $DB_NAME -e "$INSERT_ATMOS"
    $MYSQL_BIN -u $DB_USER -p"$DB_PASS" -D $DB_NAME -e "$INSERT_SUN"
fi


if [ $? -eq 0 ]; then
    echo "MySQL connection successful!"
else
    echo "Failed to connect to MySQL."
fi

sleep 5