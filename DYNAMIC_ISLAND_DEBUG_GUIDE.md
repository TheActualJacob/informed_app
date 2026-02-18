# 🔍 Dynamic Island Debugging Guide

## Current Status: Enhanced Logging Added

I've added comprehensive logging to help diagnose why the Dynamic Island isn't appearing. 

## 🧪 Test Now With Enhanced Logging

### Steps:
1. **Clean build**: Shift+Cmd+K
2. **Build & Run**: Cmd+R
3. **Share an Instagram reel**
4. **Watch Xcode Console** for detailed logs

## 📊 What to Look For

### Expected Log Sequence (Success):

```
📤 Starting background fact-check...
💾 Saved pending submission to App Group
🚩 Set new_submission_timestamp flag for main app
✅ Start processing notification sent for submission [ID]
🚀 Fact-check request sent in background
```

**Then when app becomes active:**

```
🔄 Checking for pending and completed fact-checks...
🚩 Found new submission flag (timestamp: [TIME])
🎬 Checking for pending Live Activities to start...
🔍 [LiveActivity] checkAndStartPendingLiveActivities called
📦 [LiveActivity] Found 1 total submissions in App Group
🎬 [LiveActivity] Starting Live Activity for submission: [ID]
🚀 [ActivityManager] startActivity called for: [ID]
📋 [ActivityManager] Live Activities status:
   - areActivitiesEnabled: true
✅ [ActivityManager] Live Activities are enabled, creating activity...
🎬 [ActivityManager] Requesting Live Activity from system...
✅ [ActivityManager] ✨ Live Activity started successfully! ✨
   - Activity ID: [ACTIVITY_ID]
   - Dynamic Island should now be visible!
```

### If Live Activities Are Disabled:

```
📋 [ActivityManager] Live Activities status:
   - areActivitiesEnabled: false
⚠️ [ActivityManager] Live Activities are NOT enabled
   Possible reasons:
   - iOS Simulator (not supported)
   - Personal Apple Developer accounts (limited)
   - Missing entitlements
   - Settings → [App] → Live Activities is OFF
```

### If No Pending Submissions Found:

```
📭 [LiveActivity] No pending_submissions array found in App Group
```

## 🎯 Diagnostic Checks

### Check 1: Are You on a Physical Device?
- **Simulator**: Live Activities don't work
- **iPhone 14 Pro+**: Dynamic Island works
- **Other iPhones**: Live Activity works but no Dynamic Island (shows as banner)

### Check 2: Check iOS Settings
1. Open **Settings** app
2. Scroll down to your app name
3. Look for **"Live Activities"** toggle
4. Make sure it's **ON** ✅

### Check 3: Check Build Settings
Run this command:
```bash
cd /Users/jacob/Documents/Projects/informed
grep "NSSupportsLiveActivities" informed.xcodeproj/project.pbxproj
```

Should show:
```
INFOPLIST_KEY_NSSupportsLiveActivities = YES;
INFOPLIST_KEY_NSSupportsLiveActivitiesFrequentUpdates = YES;
```

### Check 4: Verify App Group Access
The Share Extension and main app must both have access to:
```
group.com.jacob.informed
```

Check in:
- Xcode → Target: informed → Signing & Capabilities → App Groups
- Xcode → Target: InformedShare → Signing & Capabilities → App Groups

## 🐛 Common Issues & Solutions

### Issue 1: "areActivitiesEnabled: false"

**Possible Causes:**
1. Live Activities disabled in Settings
2. Running on simulator
3. iOS version < 16.1
4. Entitlements not properly configured

**Solutions:**
- Enable in Settings → [Your App] → Live Activities
- Test on physical device (iPhone 14 Pro+ for Dynamic Island)
- Verify iOS 16.1+
- Rebuild with clean build

### Issue 2: No Logs After "🔄 Checking for pending..."

**Cause:** Main app isn't detecting the new submission.

**Solution:** 
- Make sure you're **opening the main app** after sharing
- The app needs to become active to check for new submissions
- Try: Share reel → Switch to main app → Should see logs

### Issue 3: "No pending_submissions array found"

**Cause:** Share Extension isn't saving to App Group correctly.

**Check:**
```swift
// In ShareViewController logs, should see:
💾 Saved pending submission to App Group
```

If not seeing this, App Group access is broken.

### Issue 4: Activity Starts But No Dynamic Island

**Possible Causes:**
1. Not on iPhone 14 Pro or newer
2. Device has notch instead of Dynamic Island
3. Focus mode hiding Dynamic Island

**Solutions:**
- Verify device model (Settings → General → About)
- Try disabling Focus modes
- Check if Live Activity shows on Lock Screen (it should)

## 📱 Device Compatibility

### Dynamic Island (Floating UI):
- ✅ iPhone 14 Pro
- ✅ iPhone 14 Pro Max
- ✅ iPhone 15 Pro
- ✅ iPhone 15 Pro Max
- ✅ iPhone 16 Pro
- ✅ iPhone 16 Pro Max

### Live Activity (Banner/Lock Screen):
- ✅ All iOS 16.1+ devices
- ✅ Shows as expandable banner on non-Pro models
- ✅ Shows on Lock Screen

## 🔄 Test Procedure

1. **Clean Build**: Shift+Cmd+K
2. **Build & Run**: Cmd+R on physical device
3. **Keep Xcode Console Open**
4. **Share Instagram Reel** from Instagram app
5. **Immediately switch to your app** (tap on it)
6. **Watch Console Logs**

### Expected Behavior:
- Within 1-2 seconds of switching to app: Logs appear
- Within 3-5 seconds: Live Activity starts
- **Dynamic Island appears at top of screen**
- Long-press to expand and see details

## 💡 Quick Test (If Stuck)

If you're not seeing any Live Activity logs at all, try manually triggering from within the app:

Add this temporarily to HomeView.swift:
```swift
.onAppear {
    if #available(iOS 16.1, *) {
        Task {
            await ReelProcessingActivityManager.shared.startActivity(
                submissionId: "test-\(UUID().uuidString)",
                reelURL: "https://instagram.com/reel/test",
                thumbnailURL: nil
            )
        }
    }
}
```

This will:
- Test if Live Activities work at all on your device
- Show you the detailed logs
- Help diagnose if it's a permission issue vs. a timing issue

## 📞 Next Steps

After you test with the new logging:

1. **Share the console logs** with the exact output
2. We'll see if:
   - Live Activities are enabled (`areActivitiesEnabled: true/false`)
   - Submissions are being saved/found
   - Where in the process it's failing

The enhanced logging will tell us exactly what's happening! 🔍
