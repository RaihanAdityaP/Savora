#!/bin/bash
set -e

# Update/clone Flutter SDK
if cd flutter; then 
    git pull && cd ..
else 
    git clone https://github.com/RaihanAdityaP/Savora.git
fi

# Setup Flutter
flutter/bin/flutter doctor
flutter/bin/flutter clean
flutter/bin/flutter config --enable-web

# Build Flutter Web
flutter/bin/flutter build web --release

# Copy share page ke output
mkdir -p build/web/recipe
cp public/recipe/[id].html build/web/recipe/share.html

echo "✅ Build completed successfully!"