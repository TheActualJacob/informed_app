# Testing Guide: Dynamic Island with Free Account

## ✅ Quick Test Checklist

Use this to verify your Dynamic Island works perfectly with a free Apple Developer account.

---

## Test 1: Manual App Opening (Free Account Flow)

### Steps:
1. **Open Instagram** and find any reel
2. **Tap the Share button** (paper plane icon)
3. **Select "Informed"** from the share sheet
4. **Tap "Start Fact-Check"** in the Share Extension
5. **Wait for success animation** (checkmark appears briefly)
6. **Notice:** You return to Instagram (not your app)
7. **Manually tap** your app icon on home screen
8. **VERIFY:** Dynamic Island appears immediately! 🎉

### Expected Console Output:

**Share Extension:**
```
📤 Share Extension: User tapped Share
🔗 Share Extension: Extracted URL: https://www.instagram.com/reel/...
💾 Saved pending submission to App Group
🚀 Attempting to open main app via URL scheme: factcheckapp://startActivity
   ⚠️  Note: This requires a paid Apple Developer account
⚠️ Could not auto-open main app (likely using free developer account)
   User will need to manually switch back to the app
   Dynamic Island will appear when they do
```

**Main App (when you manually open it):**
```
🔄 App became active - checking for pending shared URLs
   (This works even with free Apple Developer account)
🔍 [LiveActivity] checkAndStartPendingLiveActivities called
🚀 [LiveActivity] Share Extension flag detected - new reel submitted!
📦 [LiveActivity] Found 1 total submissions in App Group
🎬 [LiveActivity] Starting Live Activity for submission: ABC123...
✅ [LiveActivity] Live Activity started successfully!
   🎉 Dynamic Island should now be visible!
```

---

## Test 2: Scene Phase Observer

### Steps:
1. **Share a reel** from Instagram (see Test 1)
2. **Don't open the app yet**
3. **Wait 10 seconds**
4. **Open your app**
5. **VERIFY:** Dynamic Island appears within 1 second

### What This Tests:
- The `onChange(of: scenePhase)` fallback mechanism
- App Group data persistence
- Immediate checking when app becomes active

---

## Test 3: Multiple Reels in Queue

### Steps:
1. **Share 3 different reels** from Instagram quickly
   - Share reel 1 → Return to Instagram
   - Share reel 2 → Return to Instagram
   - Share reel 3 → Return to Instagram
2. **Open your app** (one time)
3. **VERIFY:** Up to 3 Dynamic Islands appear simultaneously
4. **VERIFY:** Each shows different reel progress

### Expected Console Output:
```
📦 [LiveActivity] Found 3 total submissions in App Group
🎬 [LiveActivity] Starting Live Activity for submission: ABC123...
🎬 [LiveActivity] Starting Live Activity for submission: DEF456...
🎬 [LiveActivity] Starting Live Activity for submission: GHI789...
✅ [LiveActivity] checkAndStartPendingLiveActivities complete
   - Started: 3 new Live Activities
```

---

## Test 4: Background → Foreground Transition

### Steps:
1. **Have your app open** in foreground
2. **Don't close it** - just leave it open
3. **Open Instagram** (app goes to background)
4. **Share a reel** to Informed
5. **Switch back to your app** (swipe up, tap app)
6. **VERIFY:** Dynamic Island appears immediately

### What This Tests:
- The periodic checking while app is running
- Background → active transition detection
- Darwin notification system (as backup)

---

## Test 5: App Completely Closed

### Steps:
1. **Force close your app** (swipe up from app switcher)
2. **Share a reel** from Instagram
3. **Open your app** from home screen
4. **VERIFY:** Dynamic Island appears on app launch

### What This Tests:
- Cold start detection
- `onAppear` checking mechanism
- App Group persistence across app launches

---

## 🚨 Troubleshooting

### Dynamic Island Doesn't Appear

**Check 1: Is your device compatible?**
- Dynamic Island requires iPhone 14 Pro or newer
- On older devices, Live Activities appear as notifications

**Check 2: Are Live Activities enabled?**
```swift
// In console, look for:
⚠️ [ShareExtension] Live Activities not enabled

// Enable in Settings:
Settings → Face ID & Passcode → Enable "Live Activities"
```

**Check 3: Check console logs**
- Look for "App became active" message
- Look for "checkAndStartPendingLiveActivities called"
- Look for "Starting Live Activity for submission"

**Check 4: Check App Group**
```swift
// Should see this in console:
📦 [LiveActivity] Found X total submissions in App Group

// If you see:
📭 [LiveActivity] No pending_submissions array found in App Group
// → Share Extension didn't save properly
```

---

## ✅ Success Criteria

Your Dynamic Island is working correctly if:

- ✅ Share Extension saves data without errors
- ✅ Console shows "Could not auto-open main app" (expected with free account)
- ✅ Manually opening app shows "App became active" log
- ✅ Dynamic Island appears within 1-2 seconds of opening app
- ✅ Live Activity updates show progress (if backend is running)
- ✅ No crashes or errors in console

---

## 📊 Performance Expectations

| Action | Expected Time | What to See |
|--------|---------------|-------------|
| Share → Save | < 0.5s | Checkmark animation |
| Open App | Instant | App launches |
| Dynamic Island Appears | 1-2s | Live Activity visible |
| First Update | 5-10s | Progress changes |

---

## 🎯 When to Test Paid Account

**DON'T worry about testing with a paid account until:**
1. ✅ Free account flow works perfectly
2. ✅ Your backend is deployed and working
3. ✅ You're ready to publish to App Store

The code is already in place and will automatically activate when you upgrade!

---

## 📝 Quick Debug Commands

If you need to check the App Group manually:

```swift
// Add this temporarily to checkForPendingSharedURL():
let appGroupName = "group.com.jacob.informed"
if let sharedDefaults = UserDefaults(suiteName: appGroupName) {
    print("🔍 DEBUG: All App Group keys:")
    print(sharedDefaults.dictionaryRepresentation())
}
```

This will show you exactly what's stored in the shared container.
