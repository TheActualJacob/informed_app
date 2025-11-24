# Troubleshooting: Share Extension Not Processing

## The Problem

Your Share Extension logs show:
```
✅ Extracted URL: https://www.instagram.com/reel/...
✅ Saved URL to App Group
⚠️  Could not open main app directly - saved to App Group as fallback
```

But the main app doesn't process it automatically.

## Solution

The main app needs to check the App Group when it opens. I've just added `.onAppear` with `checkForPendingSharedURL()` to your `informedApp.swift`.

## Steps to Fix

### 1. Verify App Group Names Match

**In ShareViewController.swift (line ~138):**
```swift
let appGroupName = "group.com.yourcompany.informed"
```

**In informedApp.swift (line ~60):**
```swift
let appGroupName = "group.com.yourcompany.informed"
```

**BOTH MUST BE EXACTLY THE SAME!**

### 2. Replace with Your Actual App Group

1. In Xcode, select your **main app target**
2. Go to **Signing & Capabilities**
3. Look at **App Groups** - what's the actual group name? (e.g., `group.com.jacob.informed`)
4. Copy that exact name
5. Replace `"group.com.yourcompany.informed"` in BOTH files with your actual group name

### 3. Verify Both Targets Have App Group Enabled

**Main App Target:**
- Signing & Capabilities → App Groups → ✅ Should see your group CHECKED

**Share Extension Target:**  
- Signing & Capabilities → App Groups → ✅ Should see SAME group CHECKED

## Testing Steps

1. **Rebuild BOTH targets** (main app AND share extension)
2. **Delete the app from device** (to clear old data)
3. **Install fresh**
4. **Share from Instagram** again
5. **Main app should open and process automatically!**

## What Should Happen

### In Share Extension Console:
```
📤 Share Extension: User tapped Post
🔗 Share Extension: Extracted URL: https://instagram.com/...
💾 Saved URL to App Group
🔗 Opening main app with deep link
```

### In Main App Console:
```
🔗 Found pending shared URL from Share Extension: https://instagram.com/...
🔗 Received URL: factcheckapp://share?url=...
📸 Extracted Instagram URL: https://instagram.com/...
✅ Successfully uploaded reel to backend
```

## Quick Test

Add this temporary test button to your ContentView to verify App Group works:

```swift
// Add to HomeView somewhere visible
Button("Test App Group") {
    if let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.informed") {
        if let url = sharedDefaults.string(forKey: "pendingSharedURL") {
            print("✅ Can read from App Group: \(url)")
        } else {
            print("📭 App Group is empty")
        }
    } else {
        print("❌ Cannot access App Group!")
    }
}
```

If this prints "❌ Cannot access App Group!", then your App Group isn't configured correctly.

## Common Issues

### Issue: "Cannot access App Group"
**Solution:** App Group name is wrong or not configured in Xcode

### Issue: "App Group is empty"
**Solution:** Share Extension isn't saving data (wrong group name in ShareViewController)

### Issue: Main app opens but doesn't process
**Solution:** Make sure you rebuilt the main app after adding `.onAppear`

## Alternative: Manual Testing

While troubleshooting, you can manually trigger processing:

1. Share from Instagram (saves to App Group)
2. **Manually open your app** (don't wait for auto-open)
3. The `.onAppear` should check App Group and process the URL

This tests if the App Group communication works, even if automatic opening doesn't.

## Debug Version

Add more logging to see what's happening:

### In informedApp.swift, update checkForPendingSharedURL():

```swift
private func checkForPendingSharedURL() {
    let appGroupName = "group.com.yourcompany.informed" // ← USE YOUR ACTUAL GROUP
    
    print("🔍 Checking App Group: \(appGroupName)")
    
    guard let sharedDefaults = UserDefaults(suiteName: appGroupName) else {
        print("❌ FAILED to access App Group: \(appGroupName)")
        print("   Make sure App Group is configured in both targets!")
        return
    }
    
    print("✅ Successfully accessed App Group")
    
    // Check all keys in App Group (debug)
    if let keys = sharedDefaults.dictionaryRepresentation().keys {
        print("📋 Keys in App Group: \(keys)")
    }
    
    if let urlString = sharedDefaults.string(forKey: "pendingSharedURL") {
        print("🔗 Found pending URL: \(urlString)")
        
        // Rest of your code...
    } else {
        print("📭 No pending URL found in App Group")
    }
}
```

This will tell you exactly where the problem is!

## Expected Console Output

When working correctly:

```
🔍 Checking App Group: group.com.jacob.informed
✅ Successfully accessed App Group
📋 Keys in App Group: ["pendingSharedURL", "pendingSharedURLDate"]
🔗 Found pending URL: https://instagram.com/reel/...
🔗 Received URL: factcheckapp://share?url=...
📸 Extracted Instagram URL: https://instagram.com/...
⏳ Starting upload to backend...
✅ Successfully uploaded reel to backend
```

## Next Steps

1. Update App Group names in both files
2. Rebuild both targets
3. Test again
4. Check console logs
5. If still not working, add the debug logging above

The URL is being saved correctly by the Share Extension - we just need the main app to read and process it! 🚀
