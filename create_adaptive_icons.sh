#!/bin/bash
# Create proper adaptive icon foreground images
# The foreground should have the calligraphy filling more of the canvas

cd /home/dhiaa/Ayaat

# Use ImageMagick to process the source icon
# We'll take the source, trim the transparent edges, and resize to fill the adaptive icon canvas

SOURCE="assets/icon.png"
ANDROID_RES="android/app/src/main/res"

# Adaptive icon foreground sizes (108dp base)
declare -A SIZES=(
    ["drawable-mdpi"]=108
    ["drawable-hdpi"]=162
    ["drawable-xhdpi"]=216
    ["drawable-xxhdpi"]=324
    ["drawable-xxxhdpi"]=432
)

for folder in "${!SIZES[@]}"; do
    size=${SIZES[$folder]}
    output="$ANDROID_RES/$folder/ic_launcher_foreground.png"
    
    # Resize source to fit the canvas, maintaining aspect ratio
    # Use -gravity center to center the image
    # The source already has the design we want, just resize it to fill
    convert "$SOURCE" -resize "${size}x${size}" -gravity center -extent "${size}x${size}" "$output"
    
    echo "Created $output (${size}x${size})"
done

echo "Done! Adaptive icon foregrounds updated."
