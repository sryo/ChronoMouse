#!/bin/bash

set -e

# ==============================================================================
# Standalone notarization helper for an already-exported .app.
# Use release.sh for the full archive → export → notarize → DMG pipeline.
# ==============================================================================

if [ -f "config.env" ]; then
    source "config.env"
else
    echo "❌ Error: config.env not found."
    exit 1
fi

if [ -z "$APP_NAME" ]; then
    echo "❌ Error: APP_NAME is not set in config.env"
    exit 1
fi

if [ -z "$KEYCHAIN_PROFILE" ]; then
    echo "❌ Error: KEYCHAIN_PROFILE is not set in config.env"
    exit 1
fi

EXPORT_PATH="./build/Export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
ZIP_PATH="${EXPORT_PATH}/${APP_NAME}.zip"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH not found. Run ./release.sh first."
    exit 1
fi

echo "----------------------------------------------------------------"
echo "  🚀 ${APP_NAME} Notarization Helper"
echo "----------------------------------------------------------------"

echo "🤐 Zipping .app..."
(cd "$EXPORT_PATH" && zip -qr "${APP_NAME}.zip" "${APP_NAME}.app")

echo "📝 Submitting to notarytool..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1) || true
echo "$SUBMIT_OUTPUT"

SUBMIT_ID=$(echo "$SUBMIT_OUTPUT" | grep -E "^  id:" | head -1 | awk '{print $2}')
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo "✅ Notarization accepted"
else
    echo "❌ Notarization failed."
    if [ -n "$SUBMIT_ID" ]; then
        echo "Fetching notarytool log..."
        xcrun notarytool log "$SUBMIT_ID" --keychain-profile "$KEYCHAIN_PROFILE" || true
    fi
    exit 1
fi

echo "📎 Stapling .app..."
xcrun stapler staple "$APP_PATH"

echo "✅ Done. App is notarized and stapled at $APP_PATH"
