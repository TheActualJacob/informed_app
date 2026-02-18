# ⚡ Quick Start: Fix Dynamic Island (10-Minute Checklist)

## 📋 Prerequisites
- [ ] Xcode is open with `informed.xcodeproj`
- [ ] You have an iPhone 14 Pro or newer connected/available
- [ ] Main app builds successfully right now

---

## 🎯 Step 1: Create Widget Extension (3 minutes)

1. **File → New → Target**
2. Select **Widget Extension**
3. Product Name: `InformedWidget`
4. ✅ **CHECK "Include Live Activity"**
5. Language: Swift
6. Embed in: informed
7. Click **Finish** → **Activate** scheme

**Verify**: You now see `InformedWidget/` folder in Project Navigator

---

## 🎯 Step 2: Configure Shared Files (3 minutes)

Select each file below, open File Inspector (right sidebar), and set Target Membership:

### File: `informed/Models/ReelProcessingActivity.swift`
- [ ] ✅ Check `informed`
- [ ] ✅ Check `InformedWidget`

### File: `informed/Extensions/ColorPalette.swift`
- [ ] ✅ Check `informed`
- [ ] ✅ Check `InformedWidget`

### File: `informed/Utilities/HapticManager.swift`
- [ ] ✅ Check `informed`
- [ ] ✅ Check `InformedWidget`

### File: `informed/Views/ReelProcessingLiveActivity.swift`
- [ ] ❌ **UNCHECK** `informed`
- [ ] ✅ **CHECK** `InformedWidget`

**Verify**: 3 files shared, 1 file moved to widget only

---

## 🎯 Step 3: Update Widget Bundle (2 minutes)

1. Open `InformedWidget/InformedWidgetBundle.swift`
2. Replace the entire file contents with:

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

3. Delete these generated sample files:
   - [ ] Delete `InformedWidget/InformedWidget.swift`
   - [ ] Delete `InformedWidget/InformedWidgetLiveActivity.swift` (if exists)

**Verify**: InformedWidgetBundle.swift references `ReelProcessingLiveActivity()`

---

## 🎯 Step 4: Configure App Groups (1 minute)

1. Select **InformedWidget target**
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Check `group.com.jacob.informed`

**Verify**: InformedWidget now has same App Group as main app

---

## 🎯 Step 5: Build & Test (1 minute)

1. **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)
3. Select **informed** scheme (not InformedWidget)
4. Select your **physical iPhone 14 Pro or newer** as destination
5. Run (Cmd+R)

**Verify**: Build succeeds with no errors

---

## 🎯 Step 6: Test Dynamic Island (30 seconds)

1. App launches on your device
2. Tap search bar
3. Paste an Instagram reel URL
4. **👀 LOOK AT TOP OF SCREEN** within 1 second

**Expected**: Dynamic Island appears with animated progress ring

---

## ✅ Success Checklist

- [ ] No "@main" conflict errors during build
- [ ] Both `informed` and `InformedWidget` schemes build successfully
- [ ] App runs on physical iPhone 14 Pro or newer
- [ ] Dynamic Island appears when starting fact-check
- [ ] Long-press expands to show progress bar
- [ ] Completion shows checkmark
- [ ] Tapping opens app to My Reels

---

## 🐛 If It Still Doesn't Work

### Check 1: Target Membership
- Open `ReelProcessingLiveActivity.swift`
- File Inspector should show **ONLY** InformedWidget checked
- If `informed` is also checked: **UNCHECK IT**

### Check 2: Device Compatibility
```bash
Settings → General → About → Model Name
```
Must say "iPhone 14 Pro", "15 Pro", or "16 Pro" (NOT non-Pro models)

### Check 3: Live Activities Setting
```bash
Settings → [Your App Name] → Live Activities → ON
```

### Check 4: Console Logs
In Xcode, watch for:
```
✅ [ActivityManager] ✨ Live Activity started successfully! ✨
   - Activity ID: [some-uuid]
   - Dynamic Island should now be visible!
```

If you see this but no Dynamic Island:
- Widget extension wasn't properly created or embedded
- Test on different iPhone 14 Pro device
- Reboot device and try again

---

## 📞 Detailed Guides

If you need more detail on any step:

- **CREATE_WIDGET_EXTENSION_STEPS.md** - Full walkthrough with explanations
- **WIDGET_TARGET_MEMBERSHIP_GUIDE.md** - Which files go where
- **WHY_DYNAMIC_ISLAND_NOT_WORKING.md** - Technical deep-dive

---

## ⏱️ Total Time: ~10 minutes

✅ You're doing this right. Widget Extensions are required. There's no shortcut.

After these steps, your Dynamic Island will work! 🎉
