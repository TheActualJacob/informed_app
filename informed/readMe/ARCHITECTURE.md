# System Architecture - Instagram Reel Fact-Checking

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (informed)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ informedApp  │───▶│  AppDelegate │───▶│ Notification │      │
│  │   .swift     │    │   .swift     │    │   Manager    │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                    │                     │             │
│         │ onOpenURL          │ device token        │ permissions │
│         ▼                    ▼                     ▼             │
│  ┌──────────────────────────────────────────────────────┐       │
│  │          SharedReelManager (Singleton)               │       │
│  │  - Parses Instagram URLs                             │       │
│  │  - Uploads to backend                                │       │
│  │  - Manages reel status                               │       │
│  │  - Persists to UserDefaults                          │       │
│  └──────────────────────────────────────────────────────┘       │
│                           │                                      │
│         ┌─────────────────┼─────────────────┐                   │
│         ▼                 ▼                 ▼                   │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│  │Instructions │   │ SharedReels │   │  Settings   │          │
│  │    View     │   │    View     │   │    View     │          │
│  └─────────────┘   └─────────────┘   └─────────────┘          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS API Calls
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Backend Server                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  POST /api/fact-check                                            │
│  ├─ Receives: Instagram URL, device token                        │
│  ├─ Returns: fact_check_id                                       │
│  └─ Processes: Video analysis, fact-checking                     │
│                                                                   │
│  POST /api/register-device                                       │
│  ├─ Receives: device token                                       │
│  └─ Stores: Token for push notifications                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Push Notification
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Apple Push Notification Service (APNs)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Push to Device
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         iOS Device                               │
│                                                                   │
│  System notification appears ───▶ User taps                      │
│                                        │                          │
│                                        ▼                          │
│                              App opens to results                │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. User Shares Instagram Reel

```
Instagram App
    │
    │ Share Sheet
    ▼
factcheckapp://share?url=INSTAGRAM_URL
    │
    │ iOS Universal Link
    ▼
informedApp.onOpenURL()
    │
    │ Parse URL
    ▼
SharedReelManager.handleSharedURL()
    │
    ├─▶ Create SharedReel (Pending)
    │   Save to UserDefaults
    │
    ├─▶ POST to Backend API
    │   {
    │     "url": "instagram_url",
    │     "device_token": "...",
    │     "submission_id": "uuid"
    │   }
    │
    └─▶ Update status to Processing
        Show success alert
```

### 2. Backend Processes and Notifies

```
Backend receives request
    │
    ├─▶ Download Instagram video
    │
    ├─▶ Extract audio/transcript
    │
    ├─▶ Analyze claims
    │
    ├─▶ Fact-check against sources
    │
    └─▶ Generate report
        │
        ▼
Send Push Notification via APNs
    {
      "aps": {
        "alert": {
          "title": "Fact Check Complete",
          "body": "Results ready"
        }
      },
      "fact_check_id": "uuid"
    }
        │
        ▼
iOS Device receives notification
        │
        ├─▶ App in foreground: Banner shown
        │   AppDelegate.willPresent()
        │
        └─▶ App in background: System notification
            │
            │ User taps
            ▼
            AppDelegate.didReceive()
                │
                ▼
            NotificationManager.handleNotification()
                │
                ▼
            SharedReelManager.markReelAsCompleted()
                │
                ▼
            Update UI ───▶ Navigate to results
```

### 3. First-Time Setup

```
App Launch (First Time)
    │
    ├─▶ Check notification authorization
    │   UNUserNotificationCenter.notificationSettings()
    │
    ├─▶ Status = .notDetermined?
    │   │
    │   └─▶ Request permission
    │       NotificationManager.requestNotificationPermissions()
    │           │
    │           └─▶ Show iOS system alert
    │               │
    │               ├─▶ User allows
    │               │   │
    │               │   ├─▶ Register for remote notifications
    │               │   │   UIApplication.registerForRemoteNotifications()
    │               │   │
    │               │   └─▶ Receive device token
    │               │       AppDelegate.didRegisterForRemoteNotifications()
    │               │           │
    │               │           └─▶ Send to backend
    │               │               POST /api/register-device
    │               │
    │               └─▶ User denies
    │                   │
    │                   └─▶ Show status in Settings
    │                       Provide link to iOS Settings
    │
    └─▶ Continue to main app
```

## State Management

### SharedReel Status States

```
┌──────────┐
│ Pending  │ ─── Just created, waiting to upload
└──────────┘
     │
     │ Upload starts
     ▼
┌──────────┐
│Processing│ ─── Uploaded to backend, awaiting results
└──────────┘
     │
     ├─────────┐
     │         │
     │         │ Error occurred
     │         ▼
     │    ┌──────────┐
     │    │  Failed  │ ─── Upload or processing failed
     │    └──────────┘
     │
     │ Notification received
     ▼
┌──────────┐
│Completed │ ─── Results ready to view
└──────────┘
```

## Storage

### UserDefaults Keys

- `stored_user_id` - Current user's ID
- `stored_username` - Current user's username
- `stored_device_token` - APNs device token
- `stored_shared_reels` - JSON array of SharedReel objects

### SharedReel Object

```swift
struct SharedReel: Codable {
    let id: String              // UUID
    let url: String             // Instagram reel URL
    let submittedAt: Date       // Submission timestamp
    var status: FactCheckStatus // Current status
    var resultId: String?       // Backend fact_check_id
    var errorMessage: String?   // Error if failed
}
```

## Network Communication

### API Endpoints

#### 1. Submit Fact Check
```
POST https://my-backend.com/api/fact-check
Headers:
  Content-Type: application/json
  Authorization: Bearer YOUR_AUTH_TOKEN

Request Body:
{
  "url": "https://instagram.com/reel/...",
  "device_token": "abc123...",
  "submission_id": "uuid-here"
}

Response:
{
  "fact_check_id": "backend-generated-id",
  "status": "processing",
  "estimated_time": 90
}
```

#### 2. Register Device
```
POST https://my-backend.com/api/register-device
Headers:
  Content-Type: application/json

Request Body:
{
  "device_token": "abc123...",
  "platform": "ios"
}

Response:
{
  "success": true,
  "token_id": "registered-token-id"
}
```

#### 3. Push Notification Format
```json
{
  "aps": {
    "alert": {
      "title": "Fact Check Complete",
      "body": "Your Instagram reel has been analyzed"
    },
    "sound": "default",
    "badge": 1
  },
  "fact_check_id": "uuid-that-matches-submission"
}
```

## Error Handling

### Network Errors
- Connection timeout → Show "Network error" message
- Bad server response → Show "Server error" message
- Invalid JSON → Show "Unexpected response" message

### URL Parsing Errors
- Missing URL parameter → Show "Invalid share format" message
- Invalid Instagram URL → Show "Not a valid Instagram URL" message

### Permission Errors
- Notifications denied → Show banner in Settings with "Open Settings" button
- No device token → Attempt re-registration

### Backend Errors
- HTTP 400 → Show "Invalid request" with backend error message
- HTTP 401 → Show "Authentication failed"
- HTTP 500 → Show "Server error, please try again"

## UI Screens Overview

### 1. Instructions View
- Hero section with icon
- Notification status card
- 5-step instruction guide
- Quick tips section
- Permission request sheet

### 2. Shared Reels View
- List of all submissions
- Status cards with color coding
- Time stamps
- Error messages
- "View Results" button for completed items
- Empty state for first-time users

### 3. Settings View
- Account information
- Notification status
- Device token status
- Quick actions (Open Settings)
- Logout button

### 4. Success/Error Alerts
- Modal alerts for immediate feedback
- Shown after sharing from Instagram
- Clear success/error messages
