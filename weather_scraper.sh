#!/bin/bash

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

# 3. Atmospheric data

visibility=$(echo "$PAGE" \
  | grep -oP '<p class="font-label2 font-size-label2 font-weight-label2 leading-label2 case-label2 text-center justify-center text-blue-12">\K[^<]+' \
  | head -1)
pressure=$(echo "$PAGE" \
  | grep -oP '<p class="font-label2 font-size-label2 font-weight-label2 leading-label2 case-label2 text-center justify-center text-red-12">\K[^<]+' \
  | head -1)
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

# 4. Track sun times

sun_times=$(echo "$PAGE" \
  | grep -oP '<p class="text-secondary font-body1 font-size-body1 font-weight-body1 leading-body1 case-body1">\K[^<]+' )

sunrise=$(echo "$sun_times" | sed -n '1p')
sunset=$(echo "$sun_times" | sed -n '2p')

echo "--- SUN TIMES (sun_times table) ---"
echo "sunrise:        $sunrise"
echo "sunset:         $sunset"
echo ""