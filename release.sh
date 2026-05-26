#!/bin/bash

set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================

if [ -f "config.env" ]; then
    source "config.env"
else
    echo "❌ Error: config.env not found."
    echo "Please copy config.env.example to config.env and fill in your details."
    exit 1
fi

if [ -z "$APP_NAME" ] || [ "$APP_NAME" == "REPLACE_WITH_YOUR_APP_NAME" ]; then
    echo "❌ Error: APP_NAME is not set in config.env"
    exit 1
fi

if [ -z "$TEAM_ID" ] || [ "$TEAM_ID" == "REPLACE_WITH_YOUR_TEAM_ID" ]; then
    echo "❌ Error: TEAM_ID is not set in config.env"
    exit 1
fi

if [ -z "$KEYCHAIN_PROFILE" ] || [ "$KEYCHAIN_PROFILE" == "REPLACE_WITH_YOUR_PROFILE_NAME" ]; then
    echo "❌ Error: KEYCHAIN_PROFILE is not set in config.env"
    exit 1
fi

SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"

if [ ! -f "VERSION" ]; then
    echo "❌ Error: VERSION file not found"
    exit 1
fi
MARKETING_VERSION=$(tr -d '[:space:]' < VERSION)

if git rev-parse --git-dir > /dev/null 2>&1; then
    BUILD_NUMBER=$(git rev-list --count HEAD)
else
    BUILD_NUMBER=$(date +%s)
fi

# ==============================================================================

ARCHIVE_PATH="./build/${APP_NAME}.xcarchive"
EXPORT_PATH="./build/Export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
ZIP_PATH="${EXPORT_PATH}/${APP_NAME}.zip"
DMG_PATH="${EXPORT_PATH}/${APP_NAME}-${MARKETING_VERSION}.dmg"
EXPORT_OPTIONS_PLIST="${EXPORT_PATH}/ExportOptions.plist"

echo "----------------------------------------------------------------"
echo "  🚀 ${APP_NAME} v${MARKETING_VERSION} (build ${BUILD_NUMBER})"
echo "----------------------------------------------------------------"

# 0. Clean
rm -rf "./build"
mkdir -p "$EXPORT_PATH"

# 1. Archive
echo "📦 Archiving..."
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    -quiet

# 2. ExportOptions
echo "⚙️  Writing ExportOptions.plist..."
cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

# 3. Export
echo "📤 Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -quiet

# 4. Zip the .app for notarization
echo "🤐 Zipping .app for notarization..."
(cd "$EXPORT_PATH" && zip -qr "${APP_NAME}.zip" "${APP_NAME}.app")

# 5. Notarize the .app
echo "📝 Submitting .app to notarytool..."
SUBMIT_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1) || true
echo "$SUBMIT_OUTPUT"

SUBMIT_ID=$(echo "$SUBMIT_OUTPUT" | grep -E "^  id:" | head -1 | awk '{print $2}')
if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
    echo "✅ .app notarization accepted (id: $SUBMIT_ID)"
else
    echo "❌ .app notarization failed."
    if [ -n "$SUBMIT_ID" ]; then
        echo "Fetching notarytool log..."
        xcrun notarytool log "$SUBMIT_ID" --keychain-profile "$KEYCHAIN_PROFILE" || true
    fi
    exit 1
fi

# 6. Staple the .app so it works offline once extracted from DMG
echo "📎 Stapling .app..."
xcrun stapler staple "$APP_PATH"

# 7. Build DMG
echo "💿 Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# 8. Sign DMG
echo "✍️  Signing DMG..."
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

# 9. Notarize DMG
echo "📝 Submitting DMG to notarytool..."
DMG_SUBMIT=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1) || true
echo "$DMG_SUBMIT"

DMG_SUBMIT_ID=$(echo "$DMG_SUBMIT" | grep -E "^  id:" | head -1 | awk '{print $2}')
if echo "$DMG_SUBMIT" | grep -q "status: Accepted"; then
    echo "✅ DMG notarization accepted"
else
    echo "❌ DMG notarization failed."
    if [ -n "$DMG_SUBMIT_ID" ]; then
        echo "Fetching notarytool log..."
        xcrun notarytool log "$DMG_SUBMIT_ID" --keychain-profile "$KEYCHAIN_PROFILE" || true
    fi
    exit 1
fi

# 10. Staple DMG
echo "📎 Stapling DMG..."
xcrun stapler staple "$DMG_PATH"

# 11. Verify
echo "🔍 Verifying..."
codesign -dvv "$APP_PATH" 2>&1 | head -10 || true
spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH" 2>&1 | head -5 || true

echo "----------------------------------------------------------------"
echo "✅ Release complete"
echo "  Marketing version: ${MARKETING_VERSION}"
echo "  Build number:      ${BUILD_NUMBER}"
echo "  DMG:               ${DMG_PATH}"
echo "----------------------------------------------------------------"
