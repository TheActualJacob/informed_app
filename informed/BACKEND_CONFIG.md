# Backend Configuration Guide

## Overview

The app uses a centralized configuration system to manage the backend API URL. This makes it easy to update the server address without having to search through multiple files.

## Configuration File

All backend configuration is managed in `Config.swift`:

```swift
struct Config {
    static let backendURL = "http://172.20.10.2:5001"
    
    struct Endpoints {
        static let createUser = Config.endpoint("/create-user")
        static let login = Config.endpoint("/login")
        static let factCheck = Config.endpoint("/fact-check")
        static let shareReel = Config.endpoint("/share-reel")
        static let getUserReels = Config.endpoint("/get-user-reels")
        static let registerDevice = Config.endpoint("/register-device")
    }
}
```

## How to Update the Backend URL

When your backend server IP or port changes, you only need to update **one line** in `Config.swift`:

1. Open `Config.swift`
2. Find the line:
   ```swift
   static let backendURL = "http://172.20.10.2:5001"
   ```
3. Update it to your new URL:
   ```swift
   static let backendURL = "http://YOUR_NEW_IP:5001"
   ```
4. Save the file
5. Build and run the app

That's it! All API calls throughout the app will automatically use the new URL.

## How It Works

### Main App
- All API functions use `Config.Endpoints.*` to get the full URL
- Example: `Config.Endpoints.factCheck` returns `"http://172.20.10.2:5001/fact-check"`

### Share Extension
- The backend URL is automatically synced to the App Group shared storage when the app launches
- The Share Extension reads from the shared storage with a fallback to the default URL
- This ensures both the main app and Share Extension always use the same backend URL

### Files That Use Config

1. **AuthenticationView.swift**
   - `createUser()` → `Config.Endpoints.createUser`
   - `loginUser()` → `Config.Endpoints.login`

2. **Requests.swift**
   - `sendFactCheck()` → `Config.Endpoints.factCheck`

3. **NotificationManager.swift**
   - `sendDeviceTokenToBackend()` → `Config.Endpoints.registerDevice`

4. **ShareViewController.swift**
   - Reads from App Group shared storage (synced from Config)
   - Falls back to default: `http://172.20.10.2:5001`

## Common Backend URLs

Here are some common scenarios:

### Local Development (Same Network)
```swift
static let backendURL = "http://192.168.1.100:5001"  // Replace with your computer's local IP
```

### USB Tethering / Personal Hotspot
```swift
static let backendURL = "http://172.20.10.2:5001"
```

### ngrok or Tunneling Service
```swift
static let backendURL = "https://abc123.ngrok.io"
```

### Production Server
```swift
static let backendURL = "https://api.informed.app"
```

## Finding Your Local IP Address

### macOS
1. Open Terminal
2. Run: `ifconfig | grep "inet " | grep -v 127.0.0.1`
3. Look for your WiFi or Ethernet IP address

### Alternative (macOS)
1. Open System Settings → Network
2. Click on your active connection (Wi-Fi or Ethernet)
3. Find your IP address

## Troubleshooting

### "Cannot connect to server" error
1. Verify your backend Flask server is running
2. Check that your device and computer are on the same network
3. Confirm the IP address in `Config.swift` matches your computer's IP
4. Make sure port 5001 is not blocked by a firewall

### Share Extension not working
1. Make sure you've built and run the main app at least once after updating `Config.swift`
2. The backend URL is synced on app launch
3. If still having issues, try uninstalling and reinstalling the app

## Notes

- The backend URL is automatically synced to the App Group on app launch
- Both the main app and Share Extension will use the same URL
- No need to manually update the Share Extension code
- Changes to `Config.swift` require rebuilding the app
