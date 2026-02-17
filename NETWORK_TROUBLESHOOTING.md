# Network Troubleshooting Guide

## Current Issue: Request Timeout Connecting to Local Server

### What I Fixed

✅ **Updated Config.swift** - Changed backend URL from `192.168.1.222` to `192.168.1.163` (your actual server IP)
✅ **Info.plist (Main App)** - Added App Transport Security settings to allow HTTP connections
✅ **Info.plist (Share Extension)** - Added App Transport Security settings to allow HTTP connections
✅ **Added Local Network Permissions** - Added NSLocalNetworkUsageDescription to both Info.plist files

### Next Steps to Fix Connection

#### 1. **Rebuild and Deploy the App**

In Xcode:
1. Clean Build Folder: `Product` → `Clean Build Folder` (⌘⇧K)
2. Build and Run: `Product` → `Run` (⌘R)
3. Deploy to your iPhone

This is **CRITICAL** - the Info.plist changes won't take effect until you rebuild!

#### 2. **Verify Your iPhone and Mac are on the Same WiFi Network**

On iPhone:
- Settings → Wi-Fi → Check network name

On Mac:
- Click Wi-Fi icon in menu bar → Check network name

**They MUST match!**

#### 3. **Grant Local Network Permission (iOS will prompt)**

After rebuilding, iOS should show a popup asking:
> "Informed would like to find and connect to devices on your local network"

**Tap "Allow"** - This is essential for connecting to your Mac!

If you don't see this prompt:
- Settings → Informed → Local Network → Turn ON

#### 4. **Test Your Server is Accessible**

On your Mac, verify the server is running and accessible:

```bash
# Check if server is listening
curl http://192.168.1.163:5001/

# Or test a specific endpoint
curl http://192.168.1.163:5001/create-user
```

#### 5. **Check Mac Firewall Settings**

Your Mac's firewall might be blocking connections:

1. System Settings → Network → Firewall
2. If Firewall is ON:
   - Click "Options"
   - Make sure Python (or your server process) is allowed
   - OR temporarily turn off firewall for testing

#### 6. **Verify Server is Binding to All Interfaces**

Your server logs show:
```
* Running on all addresses (0.0.0.0)
* Running on http://192.168.1.163:5001
```

This is correct! ✅ The server is accessible from the network.

### Common Issues and Solutions

#### Issue: "Request timed out" Error
**Causes:**
- iPhone not on same WiFi as Mac
- iOS didn't grant Local Network permission
- Mac firewall blocking Python
- App not rebuilt after Config.swift change

**Solution:**
1. Verify same WiFi network
2. Clean build and reinstall app
3. Grant Local Network permission when prompted
4. Check Mac firewall settings

#### Issue: "Connection refused" Error
**Causes:**
- Server not running
- Server listening on localhost (127.0.0.1) instead of 0.0.0.0

**Solution:**
- Make sure server runs with: `app.run(host='0.0.0.0', port=5001)`

#### Issue: Local Network Permission Not Prompting
**Causes:**
- App already denied permission previously
- Info.plist missing NSLocalNetworkUsageDescription

**Solution:**
- Manually enable: Settings → Informed → Local Network → ON
- Or delete and reinstall the app

### Alternative: Use ngrok (Bypasses All Network Issues)

If you're still having issues, use ngrok to create a public tunnel:

```bash
# Install ngrok
brew install ngrok

# Start your backend server on port 5001
python server.py

# In another terminal, create tunnel
ngrok http 5001
```

Then update Config.swift:
```swift
static let backendURL = "https://abc123.ngrok.io"  // Use the URL ngrok gives you
```

This works from anywhere, no network configuration needed!

### Current Configuration

- **Server IP:** 192.168.1.163
- **Server Port:** 5001
- **Backend URL:** http://192.168.1.163:5001
- **App Transport Security:** Enabled (allows HTTP)
- **Local Network Permission:** Added to Info.plist

### Verification Checklist

Before testing, verify:
- [ ] Server is running and shows both 127.0.0.1 and 192.168.1.163 addresses
- [ ] iPhone and Mac on same WiFi network
- [ ] App rebuilt with ⌘⇧K → ⌘R (Clean + Run)
- [ ] Local Network permission granted when prompted
- [ ] Mac firewall allows Python/server process
- [ ] Can curl http://192.168.1.163:5001 from Mac terminal

### Debug Commands

```bash
# Check your Mac's current IP addresses
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test if server responds locally
curl -v http://192.168.1.163:5001/

# Check what's listening on port 5001
lsof -i :5001

# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### What Changed in This Fix

**informed/Config.swift:**
- Updated `backendURL` from `192.168.1.222` → `192.168.1.163`

**informed/Info.plist:**
- Added `NSAppTransportSecurity` with `NSAllowsLocalNetworking` and `NSAllowsArbitraryLoads`
- Added `NSLocalNetworkUsageDescription`

**InformedShare/Info.plist:**
- Added `NSAppTransportSecurity` with `NSAllowsLocalNetworking` and `NSAllowsArbitraryLoads`
- Added `NSLocalNetworkUsageDescription`

---

## Quick Test After Rebuild

1. Open the app on your iPhone
2. Try to create an account or login
3. Watch the Mac terminal for incoming requests
4. If you see HTTP requests in the terminal → SUCCESS! ✅
5. If you still see timeout → Check the troubleshooting steps above
