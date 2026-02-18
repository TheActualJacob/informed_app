# 🧪 Dynamic Island Testing Guide

## Prerequisites
- iPhone 14 Pro, 15 Pro, or 16 Pro (with Dynamic Island hardware)
- iOS 16.2 or later
- App installed on physical device (not simulator)
- Instagram app installed

## Test Scenarios

### ✅ Test 1: Basic Flow (App in Background)
**Expected Result**: Dynamic Island appears immediately without opening app

1. Open Instagram
2. Find any reel
3. Tap Share → More → **informed** (Share Extension)
4. Tap "Share" button
5. **OBSERVE**: Dynamic Island should appear at top of screen
   - Shows gear icon on left
   - Shows 10% progress ring on right
   - Status: "Submitting your reel..."
6. Wait 5-90 seconds
7. **OBSERVE**: Dynamic Island updates automatically
   - Progress ring fills to 100%
   - Shows checkmark icon
   - Status: "Tap to view results"
8. Tap Dynamic Island
9. **OBSERVE**: App opens to fact-check result

**Debug Logs to Check**:
```
📡 *** NEW SUBMISSION DARWIN NOTIFICATION RECEIVED ***
🔍 [LiveActivity] checkAndStartPendingLiveActivities called
🎬 [LiveActivity] Starting Live Activity for submission: [ID]
✅ [ActivityManager] ✨ Live Activity started successfully! ✨
```

---

### ✅ Test 2: App Completely Closed
**Expected Result**: Dynamic Island appears after opening app

1. Close informed app completely (swipe up from app switcher)
2. Open Instagram and share a reel to informed
3. **OBSERVE**: No Dynamic Island yet (app not running)
4. Open informed app
5. **OBSERVE**: Dynamic Island appears within 2 seconds
6. Wait for completion
7. **OBSERVE**: Dynamic Island updates to 100%

**Debug Logs to Check**:
```
🔄 App became active - checking for pending shared URLs
🔍 [LiveActivity] checkAndStartPendingLiveActivities called
📦 [LiveActivity] Found 1 total submissions in App Group
🎬 [LiveActivity] Starting Live Activity for submission: [ID]
```

---

### ✅ Test 3: Multiple Submissions
**Expected Result**: Multiple Dynamic Islands appear (up to 3 at a time)

1. Share 3 reels rapidly from Instagram
2. **OBSERVE**: Multiple Dynamic Islands appear
3. Each shows independent progress
4. As they complete, they dismiss after 8 seconds

**Debug Logs to Check**:
```
🔍 [LiveActivity] Processing submissions (current time: ...)
🎬 [LiveActivity] Starting Live Activity for submission: [ID1]
🎬 [LiveActivity] Starting Live Activity for submission: [ID2]
🎬 [LiveActivity] Starting Live Activity for submission: [ID3]
✅ [LiveActivity] checkAndStartPendingLiveActivities complete
   - Started: 3 new Live Activities
```

---

### ✅ Test 4: No Constant Haptic Feedback
**Expected Result**: Haptic only on completion, not continuously

1. Share a reel from Instagram
2. Keep app in foreground
3. **OBSERVE**: No continuous vibrations (only brief ones on completion)
4. Check logs for debouncing

**Debug Logs to Check**:
```
⏭️ [LiveActivity] Skipping check - last check was 0.5s ago (debouncing)
⏭️ [LiveActivity] Skipping check - last check was 1.2s ago (debouncing)
```

---

### ✅ Test 5: Live Activity Persists After App Reopens
**Expected Result**: Dynamic Island stays visible when closing/reopening app

1. Share reel → Dynamic Island appears
2. While fact-check is processing, close app completely
3. Reopen app
4. **OBSERVE**: Dynamic Island still visible (not ended)
5. Wait for completion
6. **OBSERVE**: Dynamic Island updates to 100%

**Debug Logs to Check**:
```
✅ [ActivityManager] Initialized (cleanup deferred)
✅ [LiveActivity] Active Live Activity found for [ID]
     ✅ Keeping existing activity - it's already visible!
```

---

### ✅ Test 6: Completion Update
**Expected Result**: Dynamic Island updates to 100% when fact-check completes

1. Share reel → Dynamic Island appears at 10%
2. Wait for backend to complete (watch console logs)
3. **OBSERVE**: Dynamic Island automatically updates
   - Progress jumps to 100%
   - Icon changes to checkmark
   - Shows "Tap to view results"
4. Dynamic Island stays visible for 8 seconds
5. Then dismisses automatically

**Debug Logs to Check**:
```
📡 *** FACT-CHECK COMPLETE DARWIN NOTIFICATION RECEIVED ***
📥 Found 1 completed fact-checks from Share Extension
✅ Synced completed fact-check [ID] to SharedReelManager
[Complete Activity logic executes]
```

---

## Common Issues & Solutions

### Issue: Dynamic Island Never Appears
**Possible Causes**:
- Running on simulator (not supported)
- Wrong device (need iPhone 14 Pro+)
- Live Activities disabled in Settings
- Personal Apple Developer account limitations

**Check**:
1. Settings → informed → Live Activities → Ensure ON
2. Device model: Must be 14 Pro, 15 Pro, or 16 Pro
3. Check logs for: `areActivitiesEnabled: false`

---

### Issue: Dynamic Island Appears Then Disappears Immediately
**Fixed!** This was the bug we just fixed. Should not happen anymore.

**If it still happens, check logs for**:
```
🧹 [ActivityManager] Cleaning up stale Live Activities...
   - Ending to ensure clean slate...  ← Should NOT see this anymore
```

---

### Issue: Dynamic Island Stuck at 10%
**Fixed!** Darwin notification now triggers immediate update.

**If it still happens, check**:
1. Share Extension logs for: `📡 Sent Darwin notification: com.jacob.informed.factCheckComplete`
2. Main app logs for: `📡 *** FACT-CHECK COMPLETE DARWIN NOTIFICATION RECEIVED ***`
3. If missing, Darwin notifications might be blocked

---

### Issue: Constant Haptic Feedback
**Fixed!** Haptic removed from automatic updates.

**If it still happens**:
- Check logs for excessive `🔍 [LiveActivity] checkAndStartPendingLiveActivities called` (should be max once per 2 seconds)
- Verify debouncing is working

---

## Success Criteria

✅ Dynamic Island appears within 2 seconds of sharing  
✅ Progress shows 10% initially  
✅ Dynamic Island persists throughout fact-check  
✅ Updates to 100% automatically when complete  
✅ No constant haptic feedback  
✅ Tapping opens app to result  
✅ Multiple submissions show multiple islands  
✅ Activity stays visible when reopening app  

---

## Logging Commands

**View real-time logs on device**:
```bash
# Terminal connected to iPhone via USB
xcrun xctrace log device --device <DEVICE_NAME> --filter "informed"
```

**Watch for key events**:
- `📡 DARWIN NOTIFICATION RECEIVED` - Darwin notification working
- `🎬 Starting Live Activity` - Activity creation
- `✅ Live Activity started successfully` - Activity visible
- `⏭️ Skipping check - debouncing` - Throttling working
- `✅ Keeping existing activity` - No premature ending

---

**Last Updated**: February 18, 2026  
**Status**: Ready for testing with all fixes applied
