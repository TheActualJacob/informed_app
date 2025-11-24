# Instagram Reel Sharing - Setup Checklist

Use this checklist to ensure everything is properly configured for the Instagram reel sharing feature.

## ✅ Phase 1: Fix Build Issues

- [ ] **Fix Info.plist Error**
  - [ ] Open Build Phases → Copy Bundle Resources
  - [ ] Remove Info.plist if present
  - [ ] Clean build folder (⇧⌘K)
  - [ ] Build successfully (⌘B)
  - [ ] See `FIX_INFO_PLIST_ERROR.md` for detailed steps

## ✅ Phase 2: Enable Push Notifications

- [ ] **Add Push Notification Capability**
  - [ ] Select project in Xcode
  - [ ] Select your target
  - [ ] Go to "Signing & Capabilities" tab
  - [ ] Click "+ Capability"
  - [ ] Search and add "Push Notifications"
  - [ ] Verify it appears in capabilities list

- [ ] **Background Modes**
  - [ ] In same "Signing & Capabilities" tab
  - [ ] Click "+ Capability"
  - [ ] Add "Background Modes"
  - [ ] Check "Remote notifications"

## ✅ Phase 3: Configure Apple Developer Portal

- [ ] **Create App Identifier**
  - [ ] Log into developer.apple.com
  - [ ] Certificates, Identifiers & Profiles
  - [ ] Identifiers → Your App ID
  - [ ] Verify "Push Notifications" is checked
  - [ ] Save changes

- [ ] **Create APNs Key (Recommended)**
  - [ ] Go to Keys section
  - [ ] Click "+" to create new key
  - [ ] Name it "Informed Push Notifications"
  - [ ] Check "Apple Push Notifications service (APNs)"
  - [ ] Register and download the key (.p8 file)
  - [ ] **IMPORTANT**: Save Key ID and Team ID for backend

  OR

- [ ] **Create APNs Certificate (Alternative)**
  - [ ] Go to Certificates section
  - [ ] Click "+" to create certificate
  - [ ] Select "Apple Push Notification service SSL"
  - [ ] Follow steps to generate and download

- [ ] **Provision Profiles**
  - [ ] Create/update provisioning profile
  - [ ] Include Push Notification capability
  - [ ] Download and install in Xcode

## ✅ Phase 4: Update Code Configuration

- [ ] **Update Backend URLs**
  
  In `NotificationManager.swift` (line ~75):
  ```swift
  // Change this:
  guard let url = URL(string: "https://my-backend.com/api/register-device")
  
  // To your actual backend:
  guard let url = URL(string: "https://YOUR_ACTUAL_BACKEND.com/api/register-device")
  ```
  
  In `SharedReelManager.swift` (line ~119):
  ```swift
  // Change this:
  guard let url = URL(string: "https://my-backend.com/api/fact-check")
  
  // To your actual backend:
  guard let url = URL(string: "https://YOUR_ACTUAL_BACKEND.com/api/fact-check")
  ```

- [ ] **Add Authorization Token**
  
  In `SharedReelManager.swift` (line ~126):
  ```swift
  // Replace with your actual auth token:
  request.setValue("Bearer YOUR_ACTUAL_AUTH_TOKEN", forHTTPHeaderField: "Authorization")
  ```

- [ ] **Update User ID from UserManager**
  
  The code uses `UserManager.currentUserId` - verify this is populated correctly after login

## ✅ Phase 5: Backend Configuration

- [ ] **Implement Device Registration Endpoint**
  ```
  POST /api/register-device
  Body: { "device_token": "...", "platform": "ios" }
  ```

- [ ] **Implement Fact Check Endpoint**
  ```
  POST /api/fact-check
  Headers: { "Authorization": "Bearer ..." }
  Body: { "url": "...", "device_token": "...", "submission_id": "..." }
  ```

- [ ] **Configure APNs on Backend**
  - [ ] Install APNs library for your backend language
  - [ ] Add the .p8 key file or certificate
  - [ ] Configure with Key ID and Team ID
  - [ ] Test connection to APNs sandbox

- [ ] **Implement Notification Sending**
  ```json
  {
    "aps": {
      "alert": {
        "title": "Fact Check Complete",
        "body": "Results are ready"
      },
      "sound": "default",
      "badge": 1
    },
    "fact_check_id": "submission_id_from_request"
  }
  ```

## ✅ Phase 6: Info.plist Configuration

- [ ] **Verify URL Scheme** (already done per your note)
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleURLSchemes</key>
          <array>
              <string>factcheckapp</string>
          </array>
      </dict>
  </array>
  ```

- [ ] **Add Instagram Query Schemes**
  ```xml
  <key>LSApplicationQueriesSchemes</key>
  <array>
      <string>instagram</string>
  </array>
  ```

- [ ] **Add Background Modes**
  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>remote-notification</string>
  </array>
  ```

## ✅ Phase 7: Testing - Simulator

- [ ] **Test URL Handling**
  ```bash
  xcrun simctl openurl booted "factcheckapp://share?url=https://instagram.com/reel/test123"
  ```
  - [ ] App opens
  - [ ] Alert shows success message
  - [ ] Check "Shared Reels" tab
  - [ ] See submission with "Pending" status

- [ ] **Test UI Navigation**
  - [ ] Open "How to Use" tab - verify instructions display
  - [ ] Open "Shared Reels" tab - verify list appears
  - [ ] Open "Settings" tab - verify settings display
  - [ ] Check notification status shows correctly

## ✅ Phase 8: Testing - Physical Device (REQUIRED for Notifications)

- [ ] **Install on Device**
  - [ ] Connect iOS device via USB
  - [ ] Select device in Xcode scheme
  - [ ] Build and run (⌘R)
  - [ ] App installs successfully

- [ ] **Test Notification Permission**
  - [ ] Launch app (first time)
  - [ ] Permission alert appears automatically
  - [ ] Tap "Allow"
  - [ ] Check console for device token
  - [ ] Copy device token from console

- [ ] **Test URL Sharing Flow**
  - [ ] Open Instagram app on device
  - [ ] Find any reel
  - [ ] Tap share button (paper plane icon)
  - [ ] Scroll to find "Informed" app
  - [ ] Tap "Informed"
  - [ ] Informed app opens
  - [ ] Success alert appears
  - [ ] Go to "Shared Reels" tab
  - [ ] See submission with "Processing" status

- [ ] **Test Push Notification (Backend Must Be Ready)**
  - [ ] Submit a reel from Instagram
  - [ ] Wait for backend to process (~1-2 minutes)
  - [ ] Backend sends push notification
  - [ ] Notification banner appears on device
  - [ ] Tap notification
  - [ ] App opens
  - [ ] Status updates to "Completed"
  - [ ] Can view results

- [ ] **Test Notification Settings**
  - [ ] Go to Settings tab
  - [ ] See device token listed
  - [ ] See notification status as "Enabled"
  - [ ] Toggle iOS notification settings
  - [ ] Return to app
  - [ ] Status updates correctly

## ✅ Phase 9: Edge Cases & Error Handling

- [ ] **Test Invalid URLs**
  - [ ] Try: `factcheckapp://share?url=notavalidurl`
  - [ ] Should show error alert
  
- [ ] **Test Missing URL Parameter**
  - [ ] Try: `factcheckapp://share`
  - [ ] Should show error alert

- [ ] **Test Network Failure**
  - [ ] Enable airplane mode
  - [ ] Share a reel
  - [ ] Should show network error
  - [ ] Status shows "Failed"

- [ ] **Test Permission Denial**
  - [ ] Fresh install
  - [ ] Deny notifications when prompted
  - [ ] Settings tab shows "Disabled"
  - [ ] "Open Settings" button works

- [ ] **Test Background Notification**
  - [ ] Submit a reel
  - [ ] Close app (swipe up)
  - [ ] Wait for notification
  - [ ] Notification appears on lock screen
  - [ ] Tap notification
  - [ ] App opens to results

## ✅ Phase 10: Production Preparation

- [ ] **Switch to Production APNs**
  - [ ] Update backend to use production APNs
  - [ ] Test with TestFlight build
  - [ ] Verify notifications arrive

- [ ] **Remove Debug Code**
  - [ ] In `informedApp.swift`, remove:
    ```swift
    // Remove this temporary code:
    UserDefaults.standard.removeObject(forKey: "stored_user_id")
    UserDefaults.standard.removeObject(forKey: "stored_username")
    ```

- [ ] **Update Version Numbers**
  - [ ] Bump version in Xcode
  - [ ] Update build number

- [ ] **App Store Requirements**
  - [ ] Add privacy policy URL
  - [ ] Add terms of service URL
  - [ ] Update `SettingsView.swift` with actual links
  - [ ] Add app description mentioning sharing feature

- [ ] **Screenshots & Marketing**
  - [ ] Screenshot of instruction screen
  - [ ] Screenshot of sharing from Instagram
  - [ ] Screenshot of notification
  - [ ] Screenshot of results

## 📋 Quick Reference

### Console Commands

**Open URL in Simulator:**
```bash
xcrun simctl openurl booted "factcheckapp://share?url=https://instagram.com/reel/test123"
```

**Clear Derived Data:**
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/informed-*
```

**View Device Logs:**
```bash
# Open Console.app
# Select your device
# Filter for "Informed" or "factcheckapp"
```

### Important Log Messages to Look For

- ✅ `Device token received: abc123...` - Push registration successful
- ✅ `Received URL: factcheckapp://...` - URL handling working
- ✅ `Successfully uploaded reel to backend` - API call succeeded
- ✅ `Notification received in foreground` - Push notification received
- ❌ `Failed to register for remote notifications` - Check capabilities
- ❌ `Error uploading reel:` - Check backend URL/auth

### Key Files Modified

1. **New Files Created:**
   - `NotificationManager.swift` - Notification handling
   - `SharedReelManager.swift` - Reel submission management
   - `AppDelegate.swift` - Push notification delegate
   - `SharedReelsView.swift` - UI for viewing submissions
   - `InstructionsView.swift` - How-to guide
   - `SettingsView.swift` - Settings and notification status

2. **Modified Files:**
   - `informedApp.swift` - Added URL handling and managers
   - `ContentView.swift` - Updated tab bar with new views

3. **Documentation:**
   - `IMPLEMENTATION_GUIDE.md` - Complete overview
   - `ARCHITECTURE.md` - System architecture
   - `FIX_INFO_PLIST_ERROR.md` - Build error solutions
   - `CHECKLIST.md` - This file

## 🎯 Success Criteria

The feature is working correctly when:

1. ✅ App builds without errors
2. ✅ User can share Instagram reel to app
3. ✅ Submission appears in "Shared Reels" tab
4. ✅ Status updates from Pending → Processing
5. ✅ Push notification arrives when complete
6. ✅ Tapping notification opens app
7. ✅ Status updates to Completed
8. ✅ Results are viewable
9. ✅ All tabs work correctly
10. ✅ Settings show accurate notification status

## 🚨 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Build fails with Info.plist error | See `FIX_INFO_PLIST_ERROR.md` |
| No device token | Enable Push Notifications capability |
| URL doesn't open app | Verify Info.plist URL scheme |
| Notifications don't arrive | Check APNs configuration on backend |
| App doesn't appear in share sheet | iOS caches share sheet, restart device |
| Notification permission not requested | Check authorization status logic |
| Backend returns 401 | Update authorization token |
| Status stuck on "Processing" | Check backend is sending notification |

## 📞 Testing Contact Points

**Things to verify with your backend team:**

1. Is device token being stored correctly?
2. Is fact-check endpoint receiving requests?
3. Are notifications being sent to APNs?
4. Is the `fact_check_id` in notification payload matching `submission_id`?
5. Are you using sandbox or production APNs?

## ✨ Optional Enhancements

Consider adding later:

- [ ] Share Extension instead of URL scheme
- [ ] Rich notifications with images
- [ ] Notification actions (View Results, Dismiss)
- [ ] Background app refresh for status updates
- [ ] Local notifications for reminders
- [ ] Deep linking to specific fact-check results
- [ ] Widget showing recent submissions
- [ ] iCloud sync of submissions across devices

---

**Need help?** Reference the detailed guides:
- Implementation details: `IMPLEMENTATION_GUIDE.md`
- Architecture diagrams: `ARCHITECTURE.md`
- Build errors: `FIX_INFO_PLIST_ERROR.md`
