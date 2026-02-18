#!/bin/bash

echo "🧹 Cleaning Informed project..."

# Navigate to project directory
cd "$(dirname "$0")"

# Clean derived data
echo "📂 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/informed-*

# Clean build folder
echo "🗑️  Cleaning build folder..."
xcodebuild clean -project informed.xcodeproj -scheme informed
xcodebuild clean -project informed.xcodeproj -scheme InformedShare
xcodebuild clean -project informed.xcodeproj -scheme InformedWidgetExtension

echo "✅ Clean complete!"
echo ""
echo "Next steps:"
echo "1. Close Xcode completely"
echo "2. Reopen the project"
echo "3. Build and run"
echo ""
echo "Or run: ./build_fresh.sh to build automatically"
