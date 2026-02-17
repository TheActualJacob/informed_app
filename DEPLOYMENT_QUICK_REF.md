# 🚀 Quick Reference: Physical iPhone Deployment

## Current Status: ✅ READY TO DEPLOY

### Your Configuration
- **Mac IP Address**: `192.168.1.163`
- **Backend Port**: `5001`
- **Config.swift**: Already correctly set! ✅

---

## Deploy in 3 Steps

### 1️⃣ Start Backend (In Terminal)
```bash
cd /Users/jacob/Documents/Projects/informed
python3 app.py
```
**Expected output**: `Running on http://0.0.0.0:5001`

### 2️⃣ Test from iPhone Safari
Open Safari on your iPhone and go to:
```
http://192.168.1.163:5001/health
```
**Expected**: `{"status": "ok"}` ✅

### 3️⃣ Deploy App from Xcode
1. Connect iPhone to Mac (USB cable)
2. Open `informed.xcodeproj` in Xcode
3. Select your iPhone from device list (top toolbar)
4. Click Run ▶️ button (or press `Cmd + R`)

**First time only**: 
- iPhone → Settings → General → VPN & Device Management
- Trust your developer certificate

---

## Troubleshooting

### Can't connect from iPhone?

**Check WiFi**: iPhone and Mac on same network?
```bash
# Mac's WiFi network:
networksetup -getairportnetwork en0

# iPhone: Settings → WiFi → check network name matches
```

**Check Firewall**: Allow Python connections
```bash
# Check firewall status:
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

**IP Changed?**: Update Config.swift
```bash
# Get current IP:
ipconfig getifaddr en0
```

### Server won't start?

**Port already in use?**
```bash
# Kill existing Flask server:
lsof -ti:5001 | xargs kill -9
```

**Database issues?**
```bash
# Databases will auto-create on first run
# Just make sure you're in the right directory
cd /Users/jacob/Documents/Projects/informed
```

---

## Testing Outside Home Network?

### Use ngrok for remote testing:
```bash
# Install (one time):
brew install ngrok

# Start Flask server first:
python3 app.py

# In new terminal, create tunnel:
ngrok http 5001

# Copy the https URL ngrok provides (e.g., https://abc123.ngrok.io)
# Update Config.swift:
static let backendURL = "https://abc123.ngrok.io"
```

---

## Quick Commands

| Task | Command |
|------|---------|
| Get Mac IP | `ipconfig getifaddr en0` |
| Start server | `python3 app.py` |
| Stop server | `Ctrl + C` or `kill $(lsof -ti:5001)` |
| Test health | `curl http://localhost:5001/health` |
| View databases | `sqlite3 users.db ".tables"` |
| Check port | `lsof -i:5001` |
| Run verifier | `python3 verify_setup.py` |

---

## API Endpoints

| Endpoint | Method | Auth Required | Purpose |
|----------|--------|---------------|---------|
| `/health` | GET | No | Health check |
| `/create-user` | POST | No | Register new user |
| `/login` | POST | No | User login |
| `/fact-check` | POST | Yes | Check a fact |
| `/history` | GET | Yes | Get user history |

**Auth**: Include `userId` and `sessionId` as query parameters

---

## Production Deployment Checklist

When you're ready to deploy to App Store:

- [ ] Get a domain name
- [ ] Deploy backend to cloud (AWS, DigitalOcean, etc.)
- [ ] Set up HTTPS/SSL certificate
- [ ] Update Config.swift with production URL
- [ ] Remove `NSAllowsArbitraryLoads` from Info.plist
- [ ] Update to production database (not SQLite)
- [ ] Add proper secrets management
- [ ] Set up monitoring and logging

---

## 🆘 Still Having Issues?

1. **Run the verifier**: `python3 verify_setup.py`
2. **Check detailed guide**: `PHYSICAL_IPHONE_DEPLOYMENT.md`
3. **View Flask logs**: Look at terminal running `python3 app.py`
4. **Check Xcode console**: View → Debug Area → Show Debug Area

---

**Last Updated**: Your backend is configured and ready!
**Your IP**: 192.168.1.163:5001 ✅
**Config.swift**: Correctly set ✅
