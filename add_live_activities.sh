#!/bin/bash

# Add Live Activities support keys to the Xcode project
# This is necessary when GENERATE_INFOPLIST_FILE = YES

PROJECT_FILE="informed.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# Add INFOPLIST_KEY for Live Activities support
# We need to add these keys after the existing INFOPLIST_KEY entries

sed -i '' '/INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone/a\
				INFOPLIST_KEY_NSSupportsLiveActivities = YES;\
				INFOPLIST_KEY_NSSupportsLiveActivitiesFrequentUpdates = YES;
' "$PROJECT_FILE"

echo "✅ Added Live Activities keys to project file"
echo "   - NSSupportsLiveActivities = YES"
echo "   - NSSupportsLiveActivitiesFrequentUpdates = YES"
