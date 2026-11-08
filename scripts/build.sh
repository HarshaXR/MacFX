#!/bin/zsh
# Builds MacFX.app into ./build and a zip for GitHub Releases into ./dist.
#   scripts/build.sh            build only
#   scripts/build.sh --install  build, copy to /Applications and launch
set -euo pipefail
cd "${0:A:h}/.."

VERSION="1.0.0"
BUNDLE_ID="com.harsha.MacFX"
APP="build/MacFX.app"

swift build -c release

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
cp "$(swift build -c release --show-bin-path)/MacFX" "$APP/Contents/MacOS/MacFX"

swift scripts/make_icon.swift build/MacFX.iconset
iconutil -c icns build/MacFX.iconset -o "$APP/Contents/Resources/MacFX.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MacFX</string>
  <key>CFBundleDisplayName</key><string>MacFX</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key><string>MacFX</string>
  <key>CFBundleIconFile</key><string>MacFX</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
rm -f dist/MacFX.zip
ditto -c -k --keepParent "$APP" dist/MacFX.zip
echo "Built $APP and dist/MacFX.zip"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x MacFX 2>/dev/null && sleep 1 || true
  rm -rf /Applications/MacFX.app
  cp -R "$APP" /Applications/
  open /Applications/MacFX.app
  echo "Installed and launched /Applications/MacFX.app"
fi
