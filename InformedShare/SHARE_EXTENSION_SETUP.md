# Share Extension Setup Guide

## What's Been Implemented

Your `ShareViewController` now:
✅ Extracts Instagram reel URLs from shared content
✅ Saves the URL to a shared App Group
✅ Opens your main app automatically with the URL
✅ Handles both URL and text-based sharing
✅ Provides user feedback and error handling

## Required Setup Steps

### 1. Create App Group

Both your main app and Share Extension need to share data through an App Group.

#### In Xcode:

1. **Select your main app target** ("informed")
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** to add a new group
6. Name it: `group.com.yourcompany.informed` (or your actual bundle ID)
7. Check the checkbox to enable it

8. **Select your Share Extension target** ("InformedShare")
9. Repeat steps 2-7 with the **SAME** App Group name

### 2. Update App Group Name in Code

In `ShareViewController.swift`, replace this line:
```swift
if let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.informed") {
```

With your actual App Group identifier (use the one you created above).

### 3. Update Info.plist for Share Extension

Your Share Extension's Info.plist needs to specify what it can accept.

Add this to your **InformedShare target's Info.plist**:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>1</integer>
            <key>NSExtensionActivationSupportsWebPageWithMaxCount</key>
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

### 4. Update Main App to Read Shared Data

In your `informedApp.swift`, add this to check for pending shares when app opens:

```swift
@main
struct informedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userManager = UserManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var reelManager = SharedReelManager.shared
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    
    var body: some Scene {
        WindowGroup {
            if userManager.isAuthenticated {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(notificationManager)
                    .environmentObject(reelManager)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
                    .onAppear {
                        // Check for pending shared URLs from Share Extension
                        checkForPendingSharedURL()
                    }
                    .task {
                        if notificationManager.authorizationStatus == .notDetermined {
                            _ = await notificationManager.requestNotificationPermissions()
                        }
                    }
                    // ... rest of your code
            }
        }
    }
    
    // Add this new method
    private func checkForPendingSharedURL() {
        // Check App Group for pending URL
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.informed"),
           let urlString = sharedDefaults.string(forKey: "pendingSharedURL") {
            
            print("🔗 Found pending shared URL: \(urlString)")
            
            // Create a URL in the format your app expects
            if let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let deepLink = URL(string: "factcheckapp://share?url=\(encodedURL)") {
                handleIncomingURL(deepLink)
            }
            
            // Clear the pending URL
            sharedDefaults.removeObject(forKey: "pendingSharedURL")
            sharedDefaults.removeObject(forKey: "pendingSharedURLDate")
            sharedDefaults.synchronize()
        }
    }
    
    // ... rest of your existing code
}
```

## How It Works

### User Flow:

1. **User opens Instagram** → Finds a reel they want to fact-check
2. **Taps Share button** → Instagram's share sheet appears
3. **Selects "Informed"** → Your Share Extension appears
4. **Taps "Post"** → ShareViewController extracts the URL
5. **Share Extension saves URL** → Stores in App Group
6. **Share Extension opens main app** → Using deep link
7. **Main app receives URL** → `onOpenURL` or `onAppear` picks it up
8. **URL is processed** → `SharedReelManager` uploads to backend
9. **User sees success alert** → "Instagram reel submitted!"

### Data Flow:

```
Instagram App
    ↓ Share
Share Extension (ShareViewController)
    ↓ Extract URL
    ↓ Save to App Group (UserDefaults with suiteName)
    ↓ Open deep link (factcheckapp://share?url=...)
Main App (informedApp)
    ↓ onOpenURL OR onAppear checks App Group
    ↓ handleIncomingURL()
SharedReelManager
    ↓ uploadReelToBackend()
Backend API
```

## Testing

### 1. Test Share Extension in Simulator

```swift
// In ShareViewController, you can add a test button:
override func viewDidLoad() {
    super.viewDidLoad()
    
    #if DEBUG
    // Test with a fake Instagram URL
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.saveSharedURL("https://www.instagram.com/reel/test123/")
        self.openMainApp(with: "https://www.instagram.com/reel/test123/")
    }
    #endif
}
```

### 2. Test on Real Device with Instagram

1. Build and install both targets on device
2. Open Instagram app
3. Find any reel
4. Tap share button (paper plane icon)
5. Look for "Informed" in the share sheet
6. If you don't see it, scroll down and tap "More" or "Edit Actions"
7. Enable "Informed"
8. Share the reel
9. Your app should open automatically and start processing

## Troubleshooting

### Share Extension doesn't appear in Instagram

**Solution:**
- Make sure your Share Extension target is installed
- Check Info.plist has correct NSExtension configuration
- Restart the device
- iOS caches share sheet extensions - it may take time to appear

### Main app doesn't open automatically

**Solution:**
- Verify your URL scheme is configured: `factcheckapp`
- Check that both targets use the same App Group
- Look for console logs in Xcode to see where it's failing

### URL is not extracted

**Solution:**
- Add more logging in `extractSharedURL` method
- Instagram sometimes shares as text, sometimes as URL
- The code handles both cases

### App Group data not sharing

**Solution:**
- Verify both targets have the same App Group identifier
- Make sure App Group is enabled in both targets' capabilities
- Check that you're using the correct suiteName in UserDefaults

## Alternative: Direct URL Scheme (Simpler)

If you want even simpler setup without Share Extension:

**Instead of Share Extension, you can:**
1. Configure your app to accept Instagram URLs via URL scheme
2. User copies link from Instagram
3. Opens your app
4. Pastes link into search bar
5. App processes it

But Share Extension provides the **best UX** - user never leaves Instagram!

## Next Steps

1. ✅ Share Extension code is ready
2. ⬜ Create App Group in Xcode
3. ⬜ Update App Group name in code
4. ⬜ Configure Share Extension Info.plist
5. ⬜ Update main app to check for pending URLs
6. ⬜ Test on device with Instagram

The Share Extension will automatically start processing when the user shares from Instagram! 🎉
