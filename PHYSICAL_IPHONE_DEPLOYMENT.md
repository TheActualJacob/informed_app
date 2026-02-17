# Physical iPhone Deployment Guide

## ✅ Your Backend is Ready!

Your Flask backend code is properly configured to accept requests from your physical iPhone. Here's what you need to ensure:

## 🔧 Backend Configuration Checklist

### 1. **Flask Server is Running Correctly** ✅
Your backend is already configured with:
```python
app.run(host='0.0.0.0', port=5001, debug=True)
```
- `host='0.0.0.0'` means it listens on ALL network interfaces (including WiFi)
- `port=5001` is the port your iOS app expects

### 2. **CORS is Enabled** ✅
```python
CORS(app)
```
This allows your iPhone to make cross-origin requests.

### 3. **Authentication Works** ✅
Your endpoints properly validate `userId` and `sessionId` parameters.

---

## 📱 iOS App Configuration

### Current Setup ✅
Your iOS app is already configured with:

1. **App Transport Security (ATS) Bypass** - Allows HTTP connections
2. **Local Network Access** - Permits connections to local servers
3. **Bonjour Services** - Enables network discovery
4. **Backend URL in Config.swift**: `http://192.168.1.163:5001`

---

## 🚀 Deployment Steps

### Step 1: Find Your Computer's Local IP Address

**On Mac:**
```bash
# Option 1: Quick command
ipconfig getifaddr en0

# Option 2: Full network info
ifconfig | grep "inet " | grep -v 127.0.0.1
```

**Your current IP in Config.swift is: `192.168.1.163`**

### Step 2: Update Config.swift (If IP Changed)

If your computer's IP address is different, update this file:

**File: `/Users/jacob/Documents/Projects/informed/informed/Config.swift`**
```swift
static let backendURL = "http://YOUR_COMPUTER_IP:5001"
```

### Step 3: Ensure iPhone and Mac are on Same WiFi Network

**Critical Requirements:**
- ✅ Mac and iPhone must be on the **same WiFi network**
- ✅ Mac's firewall must allow incoming connections on port 5001
- ✅ Router should not block local network traffic (most home routers don't)

### Step 4: Check Mac Firewall Settings

1. Open **System Settings** → **Network** → **Firewall**
2. If Firewall is ON, add Python to allowed apps:
   - Click **Options**
   - Add Python (`/usr/bin/python3` or wherever your Python is installed)
   - Or temporarily disable firewall for testing

**Command to check firewall status:**
```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### Step 5: Test Backend Connectivity from iPhone

**Before deploying the app, test if your iPhone can reach the server:**

1. Start your Flask server:
```bash
cd /path/to/your/backend
python3 app.py
```

2. On your iPhone, open Safari and navigate to:
```
http://192.168.1.163:5001/health
```

**Expected Response:**
```json
{"status": "ok"}
```

If this works, your iPhone can reach the server! ✅

---

## 🔒 Security Considerations

### For Development (Current Setup) ✅
Your current configuration is **perfect for development**:
- Allows HTTP (non-encrypted) connections
- Allows local networking
- No SSL/TLS required

### For Production Deployment ⚠️
When you deploy to the App Store, you'll need to:

1. **Use HTTPS instead of HTTP**
   - Get a domain name
   - Set up SSL certificate (Let's Encrypt is free)
   - Deploy backend to a cloud server (AWS, DigitalOcean, etc.)

2. **Remove NSAllowsArbitraryLoads**
   - This is a security risk for production
   - Only needed for local development

3. **Update Config.swift** to use production URL:
```swift
static let backendURL = "https://api.yourdomain.com"
```

---

## 🐛 Troubleshooting

### Problem: "Cannot connect to server"

**Solutions:**
1. Verify iPhone and Mac are on same WiFi
2. Check your Mac's IP hasn't changed:
   ```bash
   ipconfig getifaddr en0
   ```
3. Restart Flask server
4. Check Mac firewall settings
5. Test with Safari first (http://YOUR_IP:5001/health)

### Problem: "Request timed out"

**Solutions:**
1. Check if Flask server is running
2. Look for errors in Flask console
3. Increase timeout in NetworkService.swift (currently 300 seconds)

### Problem: "Invalid session" errors

**Solutions:**
1. Delete and reinstall app (clears old session data)
2. Check `users.db` exists and has sessions table
3. Verify session creation in `/login` and `/create-user` endpoints

### Problem: Different network (iPhone on cellular, Mac on WiFi)

**Solution:**
For testing outside your home network, you have two options:

#### Option A: Use ngrok (Recommended for testing)
```bash
# Install ngrok
brew install ngrok

# Start your Flask server (port 5001)
python3 app.py

# In another terminal, create tunnel
ngrok http 5001
```

ngrok will give you a public URL like: `https://abc123.ngrok.io`

Update Config.swift:
```swift
static let backendURL = "https://abc123.ngrok.io"
```

#### Option B: Deploy to a Cloud Server
- AWS EC2
- DigitalOcean Droplet
- Google Cloud Platform
- Heroku (free tier available)

---

## 📋 Pre-Deployment Checklist

Before deploying to your physical iPhone:

- [ ] Flask server is running on your Mac
- [ ] Mac and iPhone are on the same WiFi network
- [ ] Mac's IP address is correct in Config.swift
- [ ] Firewall allows connections on port 5001
- [ ] Safari test from iPhone returns `{"status": "ok"}`
- [ ] Database files (`users.db`, `factcheck.db`) exist
- [ ] Required Python packages are installed:
  - flask
  - flask-cors
  - sqlite3 (built-in)

---

## 🎯 Quick Start Commands

**1. Find your Mac's IP:**
```bash
ipconfig getifaddr en0
```

**2. Start Flask server:**
```bash
cd /path/to/backend
python3 app.py
```

**3. Test from iPhone Safari:**
```
http://YOUR_MAC_IP:5001/health
```

**4. If IP changed, update Config.swift and rebuild app**

---

## 📱 Deploying to Physical iPhone

### Via Xcode:

1. Connect iPhone to Mac with cable
2. Open `informed.xcodeproj` in Xcode
3. Select your physical iPhone from device dropdown (top of Xcode)
4. Ensure you're signed in with your Apple ID:
   - Xcode → Settings → Accounts → Add Apple ID
5. Select your project → Signing & Capabilities
   - Choose your Apple ID team
   - Xcode will handle provisioning profile
6. Click the Run button (▶️) or press Cmd+R

**First time deploying:**
- On your iPhone, go to: Settings → General → VPN & Device Management
- Trust your developer certificate

---

## 🌐 Network Architecture

```
┌─────────────────┐         WiFi Network          ┌──────────────────┐
│                 │      (192.168.1.x/24)         │                  │
│  Physical iPhone│◄─────────────────────────────►│   Mac Computer   │
│                 │                                │                  │
│  informed App   │    HTTP Requests              │  Flask Server    │
│  (iOS Swift)    │    Port 5001                  │  (Python)        │
│                 │                                │                  │
└─────────────────┘                                └──────────────────┘
                                                            │
                                                            ▼
                                                    ┌──────────────┐
                                                    │   SQLite DBs │
                                                    │  users.db    │
                                                    │  factcheck.db│
                                                    └──────────────┘
```

---

## ✅ Your Backend Code is Production-Ready For Development

Your Flask backend includes:
- ✅ Proper session validation
- ✅ User authentication
- ✅ History tracking with duplicate prevention
- ✅ CORS enabled
- ✅ Error handling
- ✅ Database initialization
- ✅ Health check endpoint

**No changes needed for local development!**

---

## 🎉 You're All Set!

Your backend is properly configured. Just ensure:
1. Mac and iPhone on same WiFi
2. Correct IP in Config.swift
3. Flask server running
4. Mac firewall allows port 5001

Test the `/health` endpoint from Safari first, then deploy your app!
