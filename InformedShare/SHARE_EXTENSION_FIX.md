# Share Extension Fix - Automatic URL Processing

## Problem
When sharing an Instagram reel with the app:
1. ✅ Share extension worked and sent notification
2. ❌ Main app didn't automatically process the URL when opened
3. ❌ If app was already open in background, it wouldn't check for new shares

## Root Causes

### 1. App Lifecycle Issue
The `checkForPendingSharedURL()` function was only called once in `onAppear`, which doesn't trigger when:
- App is already running in background
- User switches back to the app from another app

### 2. UserDefaults Warning
```
Couldn't read values in CFPrefsPlistSource<0x1264a9a00> (Domain: group.com.jacob.informed, User: kCFPreferencesAnyUser, ByHost: Yes, Container: (null), Contents Need Refresh: Yes)
```
This was caused by not explicitly calling `synchronize()` after writing to the shared UserDefaults.

## Solutions Implemented

### ✅ Fix 1: Monitor Scene Phase (informedApp.swift)
Added `@Environment(\.scenePhase)` and `.onChange(of: scenePhase)` to check for shared URLs every time the app becomes active:

```swift
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        print("🔄 App became active - checking for pending shared URLs")
        checkForPendingSharedURL()
    }
}
```

### ✅ Fix 2: Improved UserDefaults Handling (ShareViewController.swift)
- Store timestamp as `TimeInterval` instead of `Date` object
- Explicitly call `synchronize()` and verify the save
- Added better logging to track the save process

```swift
sharedDefaults.set(url, forKey: "pendingSharedURL")
sharedDefaults.set(Date().timeIntervalSince1970, forKey: "pendingSharedURLDate")

let success = sharedDefaults.synchronize()

if success {
    print("💾 Successfully saved URL to App Group")
    // Verify
    if let savedURL = sharedDefaults.string(forKey: "pendingSharedURL") {
        print("✅ Verified saved URL: \(savedURL)")
    }
}
```

### ✅ Fix 3: Clear Before Processing (informedApp.swift)
Clear the pending URL from App Group storage BEFORE processing it to prevent duplicate processing:

```swift
// Clear the pending URL BEFORE processing to avoid re-processing
sharedDefaults.removeObject(forKey: "pendingSharedURL")
sharedDefaults.removeObject(forKey: "pendingSharedURLDate")
sharedDefaults.synchronize()

// Now process the URL
handleIncomingURL(deepLink)
```

### ✅ Fix 4: Timestamp Validation (informedApp.swift)
Added age check to skip processing very old shared URLs (older than 1 hour):

```swift
if let timestamp = sharedDefaults.double(forKey: "pendingSharedURLDate") {
    let submittedDate = Date(timeIntervalSince1970: timestamp)
    let age = Date().timeIntervalSince(submittedDate)
    
    if age > 3600 {
        print("⏭️ Skipping old shared URL (older than 1 hour)")
        return
    }
}
```

### ✅ Fix 5: Notification-Triggered Checks (AppDelegate.swift)
When user taps the notification, post a system notification to trigger URL checking:

```swift
NotificationCenter.default.post(
    name: NSNotification.Name("CheckForPendingSharedURLs"),
    object: nil
)
```

## Testing the Fix

### Test Case 1: App Closed
1. Share Instagram reel → Share extension
2. Notification appears
3. Tap notification
4. ✅ App opens and automatically processes URL

### Test Case 2: App in Background
1. Share Instagram reel → Share extension
2. Notification appears
3. Tap notification or switch to app
4. ✅ App becomes active and processes URL

### Test Case 3: App Already Open
1. Share Instagram reel → Share extension
2. Notification appears
3. Switch to app
4. ✅ App detects scene phase change and processes URL

## Debugging Tips

### Check Console Logs
Look for these key log messages:

**Share Extension:**
```
📤 Share Extension: User tapped Post
🔗 Share Extension: Extracted URL: https://...
💾 Successfully saved URL to App Group
✅ Verified saved URL: https://...
```

**Main App:**
```
🔄 App became active - checking for pending shared URLs
🔗 Found pending shared URL from Share Extension: https://...
⏱️ Shared URL is X seconds old
✅ Cleared pending shared URL from App Group
🔗 Received URL: factcheckapp://share?url=...
```

### Common Issues

**Issue:** "Could not access App Group"
- **Fix:** Ensure both main app and share extension have the same App Group ID configured in Signing & Capabilities

**Issue:** URLs not processing
- **Fix:** Check that URL scheme `factcheckapp` is registered in Info.plist

**Issue:** Duplicate processing
- **Fix:** Make sure to clear the pending URL BEFORE processing (already fixed)

## Files Modified

1. ✅ `ShareViewController.swift` - Improved UserDefaults handling
2. ✅ `informedApp.swift` - Added scene phase monitoring and improved URL checking
3. ✅ `AppDelegate.swift` - Added notification center post when user taps notification

## Next Steps

- [ ] Remove the temporary credential clearing code in `informedApp.swift` init
- [ ] Test with real backend endpoint
- [ ] Add progress indicator in UI when processing shared URLs
- [ ] Consider adding a visual confirmation when URL is successfully queued
