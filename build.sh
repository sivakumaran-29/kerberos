#!/bin/bash
echo ">>> Installing Flutter SDK in Vercel Container..."
git clone https://github.com/flutter/flutter.git -b stable

# Add flutter to path
export PATH="$PATH:`pwd`/flutter/bin"

cd client

echo ">>> Injecting Environment Variables..."
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo "DEVICE_UUID=web-agent" >> .env

echo ">>> Getting Packages..."
flutter pub get

echo ">>> Building Web Bundle..."
flutter build web --release

echo ">>> Build Complete!"
