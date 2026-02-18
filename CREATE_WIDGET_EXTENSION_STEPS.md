# Creating Widget Extension for Dynamic Island - Step by Step

## ⚠️ CRITICAL: You Need a Widget Extension Target

Your Dynamic Island is NOT working because the Live Activity widget code is in the main app target. Apple requires a separate **Widget Extension** target for Live Activities to function.

## 🎯 Steps to Create Widget Extension

### Step 1: Create Widget Extension Target in Xcode

1. Open `informed.xcodeproj` in Xcode
2. Click on the project navigator (top-level "informed" project)
3. Click **File → New → Target**
4. Select **Widget Extension** template
5. Configure:
   - **Product Name**: `InformedWidget`
   - **Include Live Activity**: ✅ **CHECK THIS BOX** (critical!)
   - **Language**: Swift
   - **Project**: informed
   - **Embed in Application**: informed
6. Click **Finish**
7. When prompted "Activate 'InformedWidget' scheme?", click **Activate**

Xcode will create:
- `InformedWidget/` folder
- `InformedWidget.swift` (starter widget)
- `InformedWidgetBundle.swift` (entry point)
- `InformedWidgetLiveActivity.swift` (starter Live Activity - we'll replace this)
- `Info.plist` for the extension
- New build target and scheme

### Step 2: Move Live Activity Files to Widget Extension

After creating the extension:

1. **In Xcode's Project Navigator:**
   - Find `informed/Models/ReelProcessingActivity.swift`
   - Click the file in the navigator
   - In **File Inspector** (right sidebar), find **Target Membership**
   - ✅ Check **BOTH** `informed` AND `InformedWidget`
   - This allows both the app and widget to access the attributes

2. **Move the Live Activity UI:**
   - Find `informed/Views/ReelProcessingLiveActivity.swift`
   - In **Target Membership**:
     - ❌ **Uncheck** `informed` (remove from main app)
     - ✅ **Check** `InformedWidget` (add to widget extension)

3. **Delete the generated sample files:**
   - Delete `InformedWidget/InformedWidget.swift` (we don't need sample widget)
   - Delete `InformedWidget/InformedWidgetLiveActivity.swift` (we have our own)
   - Keep `InformedWidgetBundle.swift` (we'll update it)

### Step 3: Update the Widget Bundle

Replace the contents of `InformedWidget/InformedWidgetBundle.swift` with:

```swift
import WidgetKit
import SwiftUI

@main
struct InformedWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReelProcessingLiveActivity()
    }
}
```

### Step 4: Configure App Groups

The widget extension needs the same App Group to communicate with the main app:

1. Select **InformedWidget target**
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. ✅ Check `group.com.jacob.informed` (same as main app)

### Step 5: Update Info.plist Keys

The `InformedWidget/Info.plist` should have:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

(Xcode may auto-add these if you checked "Include Live Activity" during creation)

### Step 6: Configure Deployment Target

1. Select **InformedWidget target**
2. Go to **Build Settings**
3. Set **iOS Deployment Target** to `16.1` (minimum for Live Activities)

### Step 7: Clean Build

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)
3. Ensure both `informed` and `InformedWidget` schemes build successfully

### Step 8: Test on Physical Device

**CRITICAL**: Dynamic Island only works on:
- iPhone 14 Pro / Pro Max
- iPhone 15 Pro / Pro Max  
- iPhone 16 Pro / Pro Max

1. Connect your iPhone via USB or WiFi
2. Select your device as the destination
3. Run the **informed** scheme (not InformedWidget - that runs automatically)
4. Test by:
   - Opening the app
   - Pasting an Instagram reel URL in the search bar
   - Looking at the Dynamic Island at the top of the screen

## 🎨 Expected Result

After completing these steps:

✅ Build succeeds with no `@main` conflicts  
✅ Widget extension is embedded in your app  
✅ Live Activity starts when you trigger fact-checking  
✅ Dynamic Island appears with animated progress  
✅ You can long-press to expand and see details  
✅ Tap when complete to open the app  

## 🐛 Troubleshooting

### Build Error: Multiple @main attributes
- **Cause**: `ReelProcessingLiveActivity.swift` is in BOTH targets
- **Fix**: Ensure it's ONLY in `InformedWidget` target

### Build Error: Cannot find type 'ReelProcessingActivityAttributes'
- **Cause**: `ReelProcessingActivity.swift` not visible to widget extension
- **Fix**: Ensure **Target Membership** includes BOTH targets

### Runtime: Live Activity starts but no Dynamic Island
- **Cause**: Testing on wrong device or simulator
- **Fix**: Must test on iPhone 14 Pro or newer physical device

### Runtime: Permission error when starting activity
- **Cause**: Live Activities not enabled in Settings
- **Fix**: Settings → [Your App] → Live Activities → ON

## 📁 Final File Structure

```
informed/
├── informed/
│   ├── Models/
│   │   └── ReelProcessingActivity.swift  [✅ informed ✅ InformedWidget]
│   ├── Views/
│   │   ├── HomeView.swift  [✅ informed only]
│   │   └── (other views...)
│   └── (other app files...)
│
├── InformedWidget/
│   ├── InformedWidgetBundle.swift  [✅ InformedWidget only]
│   ├── ReelProcessingLiveActivity.swift  [✅ InformedWidget only - MOVED HERE]
│   └── Info.plist
│
└── InformedShare/
    └── ShareViewController.swift
```

## ✅ Checklist

Before testing:

- [ ] Widget Extension target created with "Include Live Activity" checked
- [ ] `ReelProcessingActivity.swift` has Target Membership in BOTH targets
- [ ] `ReelProcessingLiveActivity.swift` has Target Membership in InformedWidget ONLY
- [ ] `InformedWidgetBundle.swift` references `ReelProcessingLiveActivity()`
- [ ] App Groups configured on InformedWidget target: `group.com.jacob.informed`
- [ ] InformedWidget deployment target set to iOS 16.1+
- [ ] Clean build succeeds (no errors)
- [ ] Testing on physical iPhone 14 Pro or newer

## 🎉 Success Criteria

When everything is working:

1. Start fact-check in app
2. Within 1 second, Dynamic Island appears with progress ring
3. Long-press to expand - see progress bar and status
4. When complete, see checkmark and "Tap to view results"
5. Tap - app opens to My Reels tab

---

**Note**: This is the ONLY way to get Dynamic Island working. There is no shortcut - Apple requires the Widget Extension architecture.
