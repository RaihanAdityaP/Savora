#!/bin/bash
set -e

echo "Current directory: $(pwd)"
echo "List root files:"
ls -la

# Clone atau update Flutter SDK
if [ -d flutter ]; then
  echo "Updating Flutter SDK..."
  (cd flutter && git pull)
else
  echo "Cloning Flutter SDK (stable)..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Tambahkan ke PATH
export PATH="$PATH:$PWD/flutter/bin"

echo "Flutter version:"
flutter --version

echo "web..."
flutter config --enable-web

echo "Cleaning..."
flutter clean

echo "Building Flutter web..."
flutter build web --release

echo "Creating recipe directory..."
mkdir -p build/web/recipe

echo "Copying share template..."
if [ ! -f "public/recipe/recipe-share-template.html" ]; then
  echo "ERROR: public/recipe/recipe-share-template.html not found!"
  exit 1
fi
cp public/recipe/recipe-share-template.html build/web/recipe/share.html

echo "Build completed successfully!"