# Complete System Flow Diagram

## 🔄 End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER JOURNEY                                 │
└─────────────────────────────────────────────────────────────────────┘

   📱 Instagram App                    📱 Informed App
   ┌────────────┐                     ┌─────────────┐
   │            │                     │             │
   │  Find Reel │                     │ First Launch│
   │     ↓      │                     │     ↓       │
   │  Tap Share │                     │ Permission  │
   │     ↓      │                     │   Alert     │
   │   Select   │                     │     ↓       │
   │  "Informed"│────────────────────▶│   Allow     │
   │            │                     │     ↓       │
   └────────────┘                     │ Get Device  │
         │                            │   Token     │
         │ Opens App                  └─────────────┘
         │
         ▼
   ┌──────────────────────────────────────────────────┐
   │  factcheckapp://share?url=INSTAGRAM_URL          │
   └──────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │              iOS System URL Handler                     │
   │  - Validates URL scheme                                 │
   │  - Routes to registered app                             │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │         informedApp.swift: onOpenURL                    │
   │  - Receives URL                                         │
   │  - Checks scheme == "factcheckapp"                      │
   │  - Checks host == "share"                               │
   │  - Calls handleIncomingURL()                            │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      SharedReelManager.handleSharedURL()                │
   │  1. Parse URL components                                │
   │  2. Extract "url" query parameter                       │
   │  3. Validate Instagram URL                              │
   │  4. Create SharedReel(id, url, date, status: pending)   │
   │  5. Save to local storage                               │
   │  6. Call uploadReelToBackend()                          │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      SharedReelManager.uploadReelToBackend()            │
   │  - Get device token from NotificationManager            │
   │  - Create HTTP POST request                             │
   │  - Add Authorization header                             │
   │  - JSON body: {url, device_token, submission_id}        │
   │  - Set timeout: 30 seconds                              │
   │  - Send async request                                   │
   └────────────────────────────────────────────────────────┘
         │
         │ HTTP POST
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │             Backend API: /api/fact-check                │
   │  - Validate request                                     │
   │  - Store submission in database                         │
   │  - Return: {fact_check_id, status: "processing"}        │
   │  - Queue async processing job                           │
   └────────────────────────────────────────────────────────┘
         │
         │ Response: 200 OK
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      SharedReelManager (continued)                      │
   │  - Parse response JSON                                  │
   │  - Extract fact_check_id                                │
   │  - Update local SharedReel:                             │
   │    * status = processing                                │
   │    * resultId = fact_check_id                           │
   │  - Save to UserDefaults                                 │
   │  - Set lastUploadSuccess = true                         │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      informedApp (continued)                            │
   │  - Receives upload success                              │
   │  - Shows success alert:                                 │
   │    "Instagram reel submitted successfully!              │
   │     You'll be notified when complete."                  │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      User can view in "Shared Reels" tab                │
   │  SharedReelsView shows:                                 │
   │  - Status: Processing 🔵                                │
   │  - Instagram URL                                        │
   │  - Time: "Just now"                                     │
   │  - Loading spinner                                      │
   └────────────────────────────────────────────────────────┘
         │
         │ [User waits 30-120 seconds]
         │
         │ Meanwhile, backend processes...
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │         Backend Processing (Async)                      │
   │  1. Download Instagram video                            │
   │  2. Extract audio/transcript                            │
   │  3. Identify claims                                     │
   │  4. Fact-check against sources                          │
   │  5. Generate report                                     │
   │  6. Save results to database                            │
   │  7. Update status to "completed"                        │
   │  8. Prepare notification payload                        │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      Backend: Send Push Notification                    │
   │  Connect to APNs (Apple Push Notification Service)      │
   │  Payload:                                               │
   │  {                                                      │
   │    "aps": {                                             │
   │      "alert": {                                         │
   │        "title": "Fact Check Complete",                  │
   │        "body": "Results ready for your reel"            │
   │      },                                                 │
   │      "sound": "default",                                │
   │      "badge": 1                                         │
   │    },                                                   │
   │    "fact_check_id": "uuid-here"                         │
   │  }                                                      │
   └────────────────────────────────────────────────────────┘
         │
         │ APNs validates & routes
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │            APNs (Apple's Servers)                       │
   │  - Validates certificate/key                            │
   │  - Finds device by token                                │
   │  - Delivers notification                                │
   └────────────────────────────────────────────────────────┘
         │
         │ Push to device
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │              iOS Device                                 │
   │                                                         │
   │  [Notification Banner Appears]                          │
   │  ┌────────────────────────────────┐                    │
   │  │ 🔔 Fact Check Complete         │                    │
   │  │ Results ready for your reel    │                    │
   │  └────────────────────────────────┘                    │
   │                                                         │
   └────────────────────────────────────────────────────────┘
         │
         │ Delivered to app
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      AppDelegate: didReceive notification               │
   │  - Extract userInfo from notification                   │
   │  - Get fact_check_id from payload                       │
   │  - Forward to NotificationManager                       │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      NotificationManager.handleNotification()           │
   │  - Extract fact_check_id from userInfo                  │
   │  - Post NotificationCenter event:                       │
   │    "FactCheckCompleted" with fact_check_id              │
   └────────────────────────────────────────────────────────┘
         │
         │ NotificationCenter.default.post()
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      SharedReelManager (Observer)                       │
   │  - Receives "FactCheckCompleted" notification           │
   │  - Finds reel with matching resultId                    │
   │  - Updates status to .completed                         │
   │  - Saves to UserDefaults                                │
   │  - Posts "ReelFactCheckCompleted" for UI refresh        │
   └────────────────────────────────────────────────────────┘
         │
         │ @Published property changes
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      SharedReelsView (Auto-updates)                     │
   │  - SwiftUI observes @Published reels                    │
   │  - Re-renders affected ReelStatusCard                   │
   │  - Status changes to: Completed ✅                      │
   │  - Shows "View Results" button                          │
   └────────────────────────────────────────────────────────┘
         │
         │ User taps notification
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │      AppDelegate: didReceive (user tap)                 │
   │  - User tapped the notification                         │
   │  - Extract fact_check_id                                │
   │  - Post "NavigateToFactCheck" notification              │
   └────────────────────────────────────────────────────────┘
         │
         ▼
   ┌────────────────────────────────────────────────────────┐
   │         App opens to results                            │
   │  - Can navigate to specific fact check                  │
   │  - Can show detailed results view                       │
   │  - User sees complete analysis                          │
   └────────────────────────────────────────────────────────┘
```

## 🗂️ Data Storage Flow

```
┌─────────────────────────────────────────────────────────┐
│                  UserDefaults Storage                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  stored_user_id: "abc123"                                │
│  stored_username: "john_doe"                             │
│  stored_device_token: "apns_token_here..."               │
│  stored_shared_reels: [                                  │
│    {                                                     │
│      "id": "uuid-1",                                     │
│      "url": "https://instagram.com/reel/...",            │
│      "submittedAt": "2025-11-23T10:30:00Z",              │
│      "status": "completed",                              │
│      "resultId": "backend-fact-check-id",                │
│      "errorMessage": null                                │
│    },                                                    │
│    {                                                     │
│      "id": "uuid-2",                                     │
│      "url": "https://instagram.com/reel/...",            │
│      "submittedAt": "2025-11-23T11:45:00Z",              │
│      "status": "processing",                             │
│      "resultId": "backend-fact-check-id-2",              │
│      "errorMessage": null                                │
│    }                                                     │
│  ]                                                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 📱 UI State Changes

```
┌──────────────────────────────────────────────────────────┐
│              UI State Timeline                            │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  T+0s:  User shares from Instagram                       │
│         ↓                                                 │
│         App opens                                         │
│         Alert: "Submitting..."                            │
│                                                           │
│  T+2s:  Upload complete                                  │
│         ↓                                                 │
│         Alert: "Success! You'll be notified..."           │
│         SharedReelsView: Status = Processing 🔵           │
│                                                           │
│  T+30-120s: Backend processing...                        │
│             User can close app or use other features     │
│                                                           │
│  T+90s: Push notification arrives                        │
│         ↓                                                 │
│         Banner shows on screen                            │
│         Badge appears on app icon                         │
│         SharedReelsView auto-updates: Status = Completed ✅│
│                                                           │
│  T+91s: User taps notification                           │
│         ↓                                                 │
│         App opens (or comes to foreground)                │
│         Can view detailed results                         │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## 🔐 Security Flow

```
┌──────────────────────────────────────────────────────────┐
│              Security & Privacy                           │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  1. Request Permission                                    │
│     └─▶ UNUserNotificationCenter.requestAuthorization()  │
│         User must explicitly allow                        │
│                                                           │
│  2. Device Token                                          │
│     └─▶ Generated by iOS                                 │
│         Unique per app/device combination                 │
│         Can be revoked by user                            │
│                                                           │
│  3. API Authentication                                    │
│     └─▶ Bearer token in Authorization header             │
│         Validates requests                                │
│                                                           │
│  4. HTTPS Only                                            │
│     └─▶ All network requests encrypted                   │
│         TLS/SSL certificates                              │
│                                                           │
│  5. Local Storage                                         │
│     └─▶ UserDefaults encrypted by iOS                    │
│         App sandbox protection                            │
│                                                           │
│  6. APNs Security                                         │
│     └─▶ Certificate/key authentication                   │
│         Token-based (recommended)                         │
│         Or certificate-based                              │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## ⚡ Performance Timeline

```
┌──────────────────────────────────────────────────────────┐
│              Performance Metrics                          │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  URL Parsing:              < 0.1s  ⚡                     │
│  Local Storage Save:       < 0.01s ⚡                     │
│  HTTP Upload:              1-3s    🌐                     │
│  Backend Processing:       30-120s 🔄                     │
│  Push Notification:        < 5s    📬                     │
│  UI Update:                < 0.1s  ⚡                     │
│                                                           │
│  Total User Wait Time:     ~1-3s for submission          │
│  Background Processing:    ~30-120s (user doesn't wait)  │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## 🎨 User Interface States

```
┌────────────────────────────────────────────────────────────┐
│              Shared Reels View States                       │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Empty State:                                               │
│  ┌──────────────────────────────────────────────┐          │
│  │         📭                                    │          │
│  │    No Shared Reels                            │          │
│  │                                               │          │
│  │  Share Instagram reels to start               │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  Pending State:                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │  🕐 Pending                    Just now       │          │
│  │  ─────────────────────────────────────────   │          │
│  │  Instagram URL: instagram.com/reel/abc...    │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  Processing State:                                          │
│  ┌──────────────────────────────────────────────┐          │
│  │  ⚙️ Processing                 2 min ago  ⏳  │          │
│  │  ─────────────────────────────────────────   │          │
│  │  Instagram URL: instagram.com/reel/abc...    │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  Completed State:                                           │
│  ┌──────────────────────────────────────────────┐          │
│  │  ✅ Completed                  5 min ago      │          │
│  │  ─────────────────────────────────────────   │          │
│  │  Instagram URL: instagram.com/reel/abc...    │          │
│  │                                               │          │
│  │  ┌─────────────────────────────────────┐     │          │
│  │  │  📊 View Results                    │     │          │
│  │  └─────────────────────────────────────┘     │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
│  Failed State:                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │  ❌ Failed                     10 min ago     │          │
│  │  ─────────────────────────────────────────   │          │
│  │  Instagram URL: instagram.com/reel/abc...    │          │
│  │                                               │          │
│  │  ⚠️ Error: Network connection failed          │          │
│  └──────────────────────────────────────────────┘          │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## 🔄 State Machine

```
┌──────────────────────────────────────────────────────────┐
│         SharedReel Status State Machine                   │
└──────────────────────────────────────────────────────────┘

        ┌──────────┐
        │ Created  │
        └─────┬────┘
              │
              │ Saved locally
              ▼
        ┌──────────┐
        │ Pending  │◀────── Initial state
        └─────┬────┘
              │
              │ Upload started
              ▼
      ┌────────────────┐
      │   Processing   │◀──── Awaiting backend
      └───┬────────┬───┘
          │        │
          │        │ Error occurred
          │        ▼
          │   ┌─────────┐
          │   │ Failed  │◀──── Terminal state
          │   └─────────┘       (Can retry)
          │
          │ Notification received
          ▼
     ┌──────────┐
     │Completed │◀──── Terminal state
     └──────────┘      (Success!)
```

## 🌐 Network Flow

```
┌────────────────────────────────────────────────────────┐
│           Network Request Details                       │
└────────────────────────────────────────────────────────┘

iOS App                    Backend Server
   │                           │
   │  POST /api/fact-check     │
   ├──────────────────────────▶│
   │  Headers:                 │
   │    Content-Type: json     │
   │    Authorization: Bearer  │
   │  Body:                    │
   │    {                      │
   │      url: "...",          │
   │      device_token: "...", │
   │      submission_id: "..." │
   │    }                      │
   │                           │
   │       200 OK              │
   │◀──────────────────────────┤
   │  {                        │
   │    fact_check_id: "...",  │
   │    status: "processing",  │
   │    estimated_time: 90     │
   │  }                        │
   │                           │
   
   
Backend Server             APNs
   │                           │
   │  Send notification        │
   ├──────────────────────────▶│
   │  Certificate/Key auth     │
   │  {                        │
   │    aps: {...},            │
   │    fact_check_id: "..."   │
   │  }                        │
   │                           │
   │       Success             │
   │◀──────────────────────────┤
   │                           │


APNs                       iOS Device
   │                           │
   │  Push notification        │
   ├──────────────────────────▶│
   │  Encrypted payload        │
   │                           │
```

This visual guide shows the complete flow from start to finish!
