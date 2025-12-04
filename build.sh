#!/bin/bash
set -e

# Clone atau update Flutter SDK
if [ -d flutter ]; then
  echo "Updating Flutter SDK..."
  (cd flutter && git pull)
else
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
fi

# Tambahkan ke PATH supaya perintah 'flutter' bisa dipakai
export PATH="$PATH:$PWD/flutter/bin"

# Sekarang semua perintah flutter aman
flutter --version
flutter config --enable-web
flutter build web --release

# Salin file share
mkdir -p build/web/recipe
cp "public/recipe/[id].html" build/web/recipe/share.html

echo "Build completed!"