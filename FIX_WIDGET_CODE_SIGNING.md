# Fix: Widget Extension Code Signing Error

## Error Message
```
"megastat.informed.InformedWidget" failed to launch or exited before the debugger could attach
```

## Root Cause
The widget extension is missing proper entitlements configuration.

## ✅ Solution

### Option 1: Add Entitlements in Xcode (Recommended - 2 minutes)

1. **Open Xcode** with your project
2. **Select InformedWidgetExtension target** (click on project → Targets → InformedWidgetExtension)
3. **Go to 'Signing & Capabilities' tab**
4. **Click '+ Capability'** button
5. **Search for and add 'App Groups'**
6. **Check the box** for `group.com.jacob.informed`
7. **Clean and rebuild** (Shift+Cmd+K, then Cmd+B)
8. **Run on your physical device** (not simulator)

### Option 2: Manual Entitlements File (If Option 1 doesn't work)

An entitlements file has been created at:
```
InformedWidget/InformedWidget.entitlements
```

To add it to your project:

1. In Xcode Project Navigator, right-click **InformedWidget** folder
2. Select **"Add Files to 'informed'..."**
3. Navigate to and select **InformedWidget.entitlements**
4. Ensure **InformedWidgetExtension target is checked**
5. Click **Add**
6. Select **InformedWidgetExtension target**
7. Go to **Build Settings** tab
8. Search for **"Code Signing Entitlements"**
9. Set value to: `InformedWidget/InformedWidget.entitlements`
10. Clean and rebuild

## Verification

After applying the fix, verify in Xcode:

1. Select **InformedWidgetExtension target**
2. **Signing & Capabilities** tab should show:
   - ✅ **Signing**: Automatically manage signing (checked)
   - ✅ **Team**: Your development team
   - ✅ **Bundle Identifier**: megastat.informed.InformedWidget
   - ✅ **App Groups**: group.com.jacob.informed (checked)

## Then Test

1. **Clean Build Folder** (Shift+Cmd+K)
2. **Build** (Cmd+B)
3. **Select your iPhone** as destination (must be physical iPhone 14 Pro or newer)
4. **Run** (Cmd+R)
5. **Test Live Activity**:
   - Open the app
   - Paste an Instagram reel URL in search
   - **Look at Dynamic Island** - should appear within 1 second!

## Expected Result

✅ App launches successfully on device  
✅ No code signing errors  
✅ Live Activity starts  
✅ Dynamic Island appears with animated progress  
✅ Long-press expands to show details  

## If Still Failing

### Check 1: Device Provisioning
```bash
# In Xcode:
Window → Devices and Simulators → Select your iPhone
→ Ensure device shows "Ready for Development"
```

### Check 2: Bundle Identifier Match
The widget extension bundle ID should be:
```
megastat.informed.InformedWidget
```

It should be a **child** of your app's bundle ID:
```
megastat.informed
```

### Check 3: Clean Derived Data
```bash
# In Xcode:
Product → Clean Build Folder (Shift+Cmd+K)
# Then in Finder:
~/Library/Developer/Xcode/DerivedData/
# Delete the 'informed-*' folder
# Rebuild
```

### Check 4: Trust Developer Certificate on Device
On your iPhone:
```
Settings → General → VPN & Device Management
→ Find your developer certificate
→ Tap and "Trust"
```

## Why This Error Occurred

Widget extensions run as **separate processes** from the main app. They need:
- ✅ Valid code signature
- ✅ Proper entitlements (App Groups to communicate with main app)
- ✅ Same development team as main app

Without the entitlements, iOS refuses to launch the widget extension for security reasons.

## Quick Commands (After Xcode Changes)

```bash
# Clean
cd /Users/jacob/Documents/Projects/informed
rm -rf ~/Library/Developer/Xcode/DerivedData/informed-*

# Build
xcodebuild -project informed.xcodeproj -scheme informed clean build

# Then run in Xcode on your device
```

---

**Next Step**: Follow Option 1 above (add App Groups capability in Xcode). This is the fastest fix - takes 2 minutes.
