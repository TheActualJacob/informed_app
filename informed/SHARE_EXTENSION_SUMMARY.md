# Share Extension - Quick Summary

## ✅ What's Ready

Your Share Extension is now **fully implemented** and ready to use! Here's what happens:

### When User Shares from Instagram:

1. **User taps Share** in Instagram on a reel
2. **Selects "Informed"** from the share sheet
3. **ShareViewController extracts** the Instagram URL
4. **Saves to App Group** for communication between extension and main app
5. **Opens main app** automatically using deep link
6. **Main app processes** the URL and uploads to backend
7. **User sees success** alert

## 🔧 Setup Required (5 Minutes)

### Step 1: Create App Group

1. Select **main app target** → Signing & Capabilities → + Capability → App Groups
2. Add group: `group.com.yourcompany.informed`
3. Select **Share Extension target** → Signing & Capabilities → + Capability → App Groups  
4. Add **same group**: `group.com.yourcompany.informed`

### Step 2: Update App Group Names in Code

Replace `"group.com.yourcompany.informed"` in:
- `ShareViewController.swift` (line ~111)
- `informedApp.swift` (line ~57)

With your actual App Group identifier.

### Step 3: Configure Share Extension Info.plist

Add to your **InformedShare target's Info.plist**:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

## 📱 How It Works

### Two Ways URL Gets to Your App:

**Method 1: Direct Deep Link**
```
Share Extension → openMainApp() → factcheckapp://share?url=... → onOpenURL
```

**Method 2: App Group (Fallback)**
```
Share Extension → Save to App Group → Main app opens → onAppear → checkForPendingSharedURL()
```

Both methods ensure the URL is processed even if the direct deep link fails!

## 🎯 Features Implemented

✅ **URL Extraction** - Handles both URL and text from Instagram
✅ **App Group Communication** - Shares data between extension and main app
✅ **Automatic App Opening** - Opens main app after sharing
✅ **Dual URL Handling** - Deep link OR App Group checking
✅ **Error Handling** - Graceful failures with user feedback
✅ **Console Logging** - Detailed logs for debugging

## 🧪 Testing

### In Simulator:
Can't fully test Share Extension in simulator, but you can test URL handling:
```bash
xcrun simctl openurl booted "factcheckapp://share?url=https://instagram.com/reel/test"
```

### On Real Device:
1. Install both app and extension on device
2. Open Instagram
3. Find a reel
4. Tap Share → Look for "Informed"
5. Share the reel
6. Your app opens and processes it!

## 🐛 Troubleshooting

**"Informed" doesn't appear in Instagram's share sheet:**
- Restart device
- Make sure Share Extension target is installed
- iOS caches share extensions - may take time

**App doesn't open automatically:**
- Check URL scheme is configured: `factcheckapp`
- Verify App Group names match in both targets
- Check console logs for errors

**URL not extracted:**
- Instagram might format URL differently
- Code handles both URL and text formats
- Add more logging to see what's being shared

## 📊 Current Flow

```
┌─────────────┐
│  Instagram  │
│     App     │
└──────┬──────┘
       │ User taps Share
       ▼
┌─────────────┐
│   Share     │
│  Extension  │ ← Your ShareViewController
│ (Informed)  │
└──────┬──────┘
       │
       ├─> Extract Instagram URL
       ├─> Save to App Group
       └─> Open deep link
           │
           ▼
    ┌──────────────┐
    │  Main App    │ ← informedApp.swift
    │  (Informed)  │
    └──────┬───────┘
           │
           ├─> onOpenURL receives URL
           │   OR
           ├─> onAppear checks App Group
           │
           ▼
    ┌──────────────┐
    │SharedReel    │
    │  Manager     │
    └──────┬───────┘
           │
           ├─> Create SharedReel
           ├─> Upload to backend
           └─> Show success alert
                  │
                  ▼
           ┌──────────────┐
           │   Backend    │
           │     API      │
           └──────────────┘
```

## ✨ Benefits Over URL Scheme Only

**Share Extension advantages:**
- ✅ User never leaves Instagram
- ✅ Appears directly in share sheet
- ✅ No need to copy/paste
- ✅ Better UX - feels native
- ✅ Automatic processing

**URL Scheme (factcheckapp://) still needed for:**
- Fallback if Share Extension fails
- Testing in simulator
- Deep linking from other apps
- Direct URL handling

## 🎉 You're Done!

Once you complete the 3 setup steps above, sharing from Instagram will **automatically start processing** in your app!

See `SHARE_EXTENSION_SETUP.md` for more detailed instructions.
