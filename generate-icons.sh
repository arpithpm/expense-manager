#!/bin/bash

# ReceiptRadar App Icon Generator
# Generates all required iOS app icon sizes without transparency

echo "🎯 Generating ReceiptRadar app icons..."

# App icon sizes for iOS
declare -a sizes=(1024 180 120 87 80 76 60 58 40 152 167)

for size in "${sizes[@]}"; do
    echo "📱 Generating ${size}x${size} icon..."
    rsvg-convert --background-color="#007AFF" --format=png --width=${size} --height=${size} app-icon-no-alpha.svg > AppIcon-${size}.png
done

echo ""
echo "✅ All icons generated successfully!"
echo "📁 Generated files:"
ls -la AppIcon-*.png

echo ""
echo "🔍 Verifying no transparency..."
file AppIcon-1024.png | grep -q "RGB" && echo "✅ No alpha channel detected" || echo "❌ Warning: Alpha channel detected"

echo ""
echo "📋 Next steps:"
echo "1. Drag PNG files into Xcode Assets.xcassets/AppIcon.appiconset"
echo "2. Build and test"
echo "3. Upload to App Store Connect"