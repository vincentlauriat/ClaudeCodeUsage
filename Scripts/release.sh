#!/usr/bin/env bash
# Build a signed, notarized, Sparkle-ready ClaudeCodeUsage.dmg.
#
# Usage: ./Scripts/release.sh <version>
#   e.g. ./Scripts/release.sh 1.0.0
#
# One-time setup (see docs/RELEASE.md or RTKInfos' for the original writeup):
#   1. Sparkle EdDSA signing key:
#      ClaudeCodeUsage reuses the MarkdownViewer EdDSA key (Keychain account
#      "MarkdownViewer"); its public half is in Info.plist > SUPublicEDKey
#      (9PD2SBwLL4XoycyAGzaE+gO7ctuxSfuFMMajiZdXhXQ=). Do NOT regenerate it —
#      that would break auto-update for every app sharing this key.
#
#   2. Notarization uses the existing keychain profile "AppliMacVincentGithub"
#      (shared across Vincent's apps). To recreate it:
#        xcrun notarytool store-credentials "AppliMacVincentGithub" \
#          --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
#
# Override defaults:
#   SIGNING_IDENTITY="Developer ID Application: …" ./Scripts/release.sh 1.0.0
#   NOTARY_PROFILE="SomeOtherProfile"               ./Scripts/release.sh 1.0.0

set -euo pipefail

VERSION="${1:?Usage: ./Scripts/release.sh <version>  (e.g. 1.0.0)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Sanity check: project.yml must declare the same MARKETING_VERSION
if ! grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml; then
  echo "✗ MARKETING_VERSION in project.yml does not match $VERSION" >&2
  grep "MARKETING_VERSION" project.yml | sed 's/^/    /' >&2
  echo "  Bump MARKETING_VERSION in project.yml first, then re-run." >&2
  exit 1
fi

# 2. Regenerate Xcode project
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✗ xcodegen not found. Install with: brew install xcodegen" >&2
  exit 1
fi
echo "→ xcodegen generate"
xcodegen generate >/dev/null

# 3. Build Release
rm -rf "$ROOT/build"
# CODE_SIGNING_ALLOWED=NO works around the macOS Sequoia com.apple.provenance
# xattr that codesign --force rejects. We sign manually below after a ditto scrub.
echo "→ xcodebuild Release"
xcodebuild -project ClaudeCodeUsage.xcodeproj \
  -scheme ClaudeCodeUsage \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5

APP="$ROOT/build/Build/Products/Release/ClaudeCodeUsage.app"
if [ ! -d "$APP" ]; then
  echo "✗ Build did not produce $APP" >&2
  exit 1
fi

# 4. Stage to a clean directory (strips com.apple.provenance xattrs)
SIGNING_IDENTITY="${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID certificate, e.g. SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./Scripts/release.sh $VERSION}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"

STAGING_DIR="$(mktemp -d)"
STAGING="$STAGING_DIR/ClaudeCodeUsage.app"
echo "→ Staging to $STAGING_DIR"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

# Apple's timestamp server is intermittently flaky — retry up to 5 times.
codesign_ts() {
  local target="$1"
  local attempt
  for attempt in 1 2 3 4 5; do
    if codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$target" 2>&1; then
      return 0
    fi
    if [ "$attempt" -lt 5 ]; then
      echo "  ↻ codesign failed (attempt $attempt/5), retrying in 5s…"
      sleep 5
    fi
  done
  echo "✗ codesign $target failed after 5 attempts" >&2
  return 1
}

# 5. Sign Sparkle.framework nested binaries (deepest first — required by notarization)
echo "→ Codesigning Sparkle.framework nested binaries"
SPARKLE_FW="$STAGING/Contents/Frameworks/Sparkle.framework"
SPARKLE_VER="$SPARKLE_FW/Versions/B"
codesign_ts "$SPARKLE_VER/Autoupdate"
codesign_ts "$SPARKLE_VER/XPCServices/Downloader.xpc"
codesign_ts "$SPARKLE_VER/XPCServices/Installer.xpc"
codesign_ts "$SPARKLE_VER/Updater.app"
codesign_ts "$SPARKLE_FW"

# 6. Sign the app itself
echo "→ Codesigning ClaudeCodeUsage.app with Developer ID + Hardened Runtime"
codesign_ts "$STAGING"
codesign --verify --strict --deep "$STAGING"

# 7. Package as DMG
DMG="$ROOT/ClaudeCodeUsage-$VERSION.dmg"
rm -f "$DMG"

DMG_VOLNAME="ClaudeCodeUsage $VERSION"
DMG_LAYOUT_DIR="$STAGING_DIR/dmg-layout"
mkdir -p "$DMG_LAYOUT_DIR"
ditto --norsrc --noextattr --noacl "$STAGING" "$DMG_LAYOUT_DIR/ClaudeCodeUsage.app"
ln -s /Applications "$DMG_LAYOUT_DIR/Applications"

echo "→ Creating DMG"
RW_DMG="$STAGING_DIR/temp.dmg"
hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$DMG_LAYOUT_DIR" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

DMG_MOUNT=$(hdiutil attach -nobrowse -noverify -noautoopen "$RW_DMG" \
  | awk -F '\t' 'END {print $NF}')

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$DMG_VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 100, 740, 480}
        set view_options to the icon view options of container window
        set arrangement of view_options to not arranged
        set icon size of view_options to 128
        set position of item "ClaudeCodeUsage.app" of container window to {140, 200}
        set position of item "Applications" of container window to {400, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DMG_MOUNT" -quiet

echo "→ Converting to compressed DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" >/dev/null
rm -rf "$STAGING_DIR"

# 8. Notarize + staple
echo "→ Submitting to Apple notary service (2–5 min)"
xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "→ Stapling notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 9. Sparkle EdDSA signature + appcast.xml
SPARKLE_VERSION="2.9.1"
SPARKLE_TOOLS="$ROOT/.sparkle-tools"
if [ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]; then
  echo "→ Downloading Sparkle $SPARKLE_VERSION tools"
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS"
fi

echo "→ Signing DMG with Sparkle EdDSA key"
SPARKLE_SIG_LINE=$("$SPARKLE_TOOLS/bin/sign_update" --account "MarkdownViewer" "$DMG")

# sparkle:version must be CFBundleVersion (monotonic integer), NOT the marketing version.
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")

echo "→ Writing appcast.xml (sparkle:version=$BUILD_NUMBER, shortVersion=$VERSION)"
PUB_DATE=$(date -R)
cat > "$ROOT/appcast.xml" <<APPCAST
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ClaudeCodeUsage</title>
    <link>https://raw.githubusercontent.com/vincentlauriat/ClaudeCodeUsage/main/appcast.xml</link>
    <description>ClaudeCodeUsage release feed</description>
    <language>en</language>
    <item>
      <title>v$VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/vincentlauriat/ClaudeCodeUsage/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure
        url="https://github.com/vincentlauriat/ClaudeCodeUsage/releases/download/v$VERSION/ClaudeCodeUsage-$VERSION.dmg"
        type="application/octet-stream"
        $SPARKLE_SIG_LINE />
    </item>
  </channel>
</rss>
APPCAST

DMG_SIZE=$(ls -lh "$DMG" | awk '{print $5}')
echo ""
echo "✅ Built, signed, notarized, stapled, Sparkle-signed: $DMG ($DMG_SIZE)"
echo "✅ appcast.xml updated for v$VERSION"
echo ""
echo "Next steps:"
echo "  1. gh release create v$VERSION ./ClaudeCodeUsage-$VERSION.dmg --title \"v$VERSION\" --notes \"Release notes here\""
echo "  2. git add appcast.xml && git commit -m 'release: appcast for v$VERSION' && git push"
echo ""
echo "Sparkle clients on older versions will be offered the update on next check."
