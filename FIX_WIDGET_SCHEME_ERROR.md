# FIX: Widget Extension Launch Error

## Error Message
```
SendProcessControlEvent:toPid: encountered an error: 
Error Domain=com.apple.dt.deviceprocesscontrolservice Code=8 
"Failed to show Widget 'megastat.informed.InformedWidget'"
```

## Root Cause
You're trying to run the **InformedWidgetExtension** scheme directly. Widget extensions for Live Activities cannot be run standalone - they only activate when the main app starts a Live Activity.

## ✅ Solution

### Step 1: Change Active Scheme in Xcode

**At the top of Xcode window** (next to the Run/Stop buttons):

Current (WRONG):
```
InformedWidgetExtension > Jacob's iPhone
```

Should be (CORRECT):
```
informed > Jacob's iPhone
```

**To change:**
1. Click on the scheme dropdown (where it says "InformedWidgetExtension")
2. Select **"informed"** from the list
3. Ensure your **physical iPhone** is selected as the destination

### Step 2: Clean Build
- Press: **Shift + Cmd + K** (Clean Build Folder)

### Step 3: Build
- Press: **Cmd + B** (Build)

### Step 4: Run Main App
- Press: **Cmd + R** (Run)
- The **main app** will launch on your device
- The **widget extension** will be embedded automatically

### Step 5: Test Live Activity
1. App opens on your device
2. Tap the search bar
3. Paste an Instagram reel URL
4. Submit/search
5. **Look at Dynamic Island** - it should appear within 1 second!

## Why This Happens

Widget extensions are **not standalone apps**. They are:
- Embedded in the main app bundle
- Launched by iOS when needed (when main app starts a Live Activity)
- Only run when there's an active Live Activity to display

When you try to run the widget extension scheme directly, iOS tries to launch it as a widget, but it only contains Live Activity code (not a home screen widget), so it fails.

## Correct Workflow

```
You run: "informed" scheme
    ↓
Main app launches on device
    ↓
User triggers fact-check in app
    ↓
App calls Activity.request()
    ↓
iOS automatically launches widget extension
    ↓
Widget extension renders Dynamic Island
    ↓
✨ Dynamic Island appears!
```

## Verification

After running the **informed** scheme, check Console logs in Xcode for:

```
✅ [ActivityManager] ✨ Live Activity started successfully! ✨
   - Activity ID: [uuid]
   - Dynamic Island should now be visible!
```

If you see this log, the Live Activity started correctly and the Dynamic Island should be rendering.

## Quick Reference: Which Scheme to Run

| Scheme | When to Use | What It Does |
|--------|-------------|--------------|
| **informed** | ✅ **Normal testing** | Launches main app, embeds widget extension |
| InformedShare | Testing share extension only | Opens share sheet |
| InformedWidgetExtension | ❌ **Don't use** | Widget extensions can't run standalone |

---

## Next Step

1. **Switch to "informed" scheme** in Xcode
2. **Run (Cmd+R)** on your physical device
3. **Test Live Activity** by pasting Instagram URL
4. **Dynamic Island should work!** 🎉

The widget extension will load automatically when needed - you never run it directly.
