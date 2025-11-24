# Project File Structure

## New Files Added (7 Swift Files)

```
informed/
│
├── App Entry Point
│   ├── informedApp.swift              [MODIFIED] - Main app, URL handling
│   └── AppDelegate.swift              [NEW] - Push notification delegate
│
├── Managers (Singleton Services)
│   ├── NotificationManager.swift      [NEW] - Notification permissions & device token
│   ├── SharedReelManager.swift        [NEW] - Reel submission & status tracking
│   └── UserManager.swift              [EXISTING] - User authentication
│
├── Views
│   ├── ContentView.swift              [MODIFIED] - Tab bar with 5 tabs
│   ├── AuthenticationView.swift       [EXISTING] - Sign up/login
│   ├── InstructionsView.swift         [NEW] - How to use the app
│   ├── SharedReelsView.swift          [NEW] - List of submitted reels
│   └── SettingsView.swift             [NEW] - Notification settings
│
├── API
│   └── Requests.swift                 [EXISTING] - Backend API calls
│
└── Documentation
    ├── IMPLEMENTATION_GUIDE.md        [NEW] - Complete overview
    ├── ARCHITECTURE.md                [NEW] - System diagrams
    ├── CHECKLIST.md                   [NEW] - Setup checklist
    ├── QUICK_TEST_GUIDE.md            [NEW] - Quick testing guide
    └── FIX_INFO_PLIST_ERROR.md        [NEW] - Build error solutions
```

## File Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                      informedApp.swift                       │
│  - App entry point                                           │
│  - Integrates AppDelegate                                    │
│  - Handles .onOpenURL                                        │
│  - Shows alerts                                              │
└────────────┬───────────────────────┬────────────────────────┘
             │                       │
             ▼                       ▼
┌──────────────────────┐   ┌──────────────────────┐
│   AppDelegate.swift   │   │  ContentView.swift   │
│  - UNUserNotification │   │  - Tab navigation    │
│    CenterDelegate     │   │  - 5 tabs            │
│  - Receives device    │   └──────────┬───────────┘
│    tokens             │              │
│  - Handles incoming   │              │
│    notifications      │      ┌───────┼───────┬───────────┐
└──────────┬────────────┘      │       │       │           │
           │                   │       │       │           │
           │                   ▼       ▼       ▼           ▼
           │        ┌──────────────────────────────────────────┐
           │        │ InstructionsView | SharedReelsView | ... │
           │        └──────────────────────────────────────────┘
           │                   │                │
           │                   ▼                ▼
           │        ┌─────────────────────────────────────────┐
           └───────▶│      Manager Layer (Singletons)          │
                    ├─────────────────────────────────────────┤
                    │  NotificationManager.shared              │
                    │  - Request permissions                   │
                    │  - Save device token                     │
                    │  - Handle notifications                  │
                    ├─────────────────────────────────────────┤
                    │  SharedReelManager.shared                │
                    │  - Parse URLs                            │
                    │  - Upload to backend                     │
                    │  - Track status                          │
                    │  - Persist to UserDefaults               │
                    ├─────────────────────────────────────────┤
                    │  UserManager                             │
                    │  - User authentication                   │
                    │  - User ID management                    │
                    └─────────────────────────────────────────┘
                                   │
                                   │ HTTPS API
                                   ▼
                    ┌─────────────────────────────────────────┐
                    │          Backend Server                  │
                    │  - POST /api/fact-check                  │
                    │  - POST /api/register-device             │
                    └─────────────────────────────────────────┘
```

## Data Flow by Feature

### 1. URL Handling Flow
```
Instagram Share
    ↓
iOS opens: factcheckapp://share?url=...
    ↓
informedApp.onOpenURL { url in
    handleIncomingURL(url)
}
    ↓
SharedReelManager.handleSharedURL(url)
    ↓
- Parse URL
- Create SharedReel
- Upload to backend
- Show alert
```

### 2. Notification Flow
```
Backend sends push notification
    ↓
APNs delivers to device
    ↓
AppDelegate.didReceive(response:)
    ↓
NotificationManager.handleNotification(userInfo:)
    ↓
Post NotificationCenter event
    ↓
SharedReelManager observes event
    ↓
Updates reel status to "Completed"
    ↓
UI refreshes automatically
```

### 3. Permission Flow
```
App launches (first time)
    ↓
informedApp.task {
    if status == .notDetermined {
        requestPermissions()
    }
}
    ↓
NotificationManager.requestNotificationPermissions()
    ↓
iOS shows system alert
    ↓
User taps "Allow"
    ↓
UIApplication.registerForRemoteNotifications()
    ↓
AppDelegate.didRegisterForRemoteNotifications(deviceToken:)
    ↓
NotificationManager.saveDeviceToken(tokenString)
    ↓
POST to backend /api/register-device
```

## View Hierarchy

```
TabView (5 tabs)
│
├── Tab 1: InstructionsView
│   ├── Header with icon
│   ├── NotificationStatusCard
│   ├── 5 InstructionSteps
│   └── Tips Section
│   └── Sheet: NotificationPermissionSheet
│
├── Tab 2: HomeView (existing)
│   └── [Your existing feed]
│
├── Tab 3: SharedReelsView
│   ├── NavigationView
│   ├── ScrollView of ReelStatusCards
│   │   ├── Status icon & text
│   │   ├── Time ago
│   │   ├── Instagram URL
│   │   ├── Error message (if failed)
│   │   └── "View Results" button (if completed)
│   └── Empty state
│
├── Tab 4: HistoryView (existing)
│   └── [Your existing history]
│
└── Tab 5: NotificationSettingsView
    ├── NavigationView
    ├── Account Section
    │   ├── Username
    │   └── User ID
    ├── Notifications Section
    │   ├── Permission status
    │   ├── "Open Settings" button
    │   └── Device token display
    ├── About Section
    │   ├── Version
    │   ├── Privacy Policy
    │   └── Terms of Service
    └── Logout Button
```

## Manager State

### NotificationManager (@MainActor, ObservableObject)
```swift
@Published var deviceToken: String?
@Published var notificationPermissionGranted: Bool
@Published var authorizationStatus: UNAuthorizationStatus

Functions:
- requestNotificationPermissions() async -> Bool
- saveDeviceToken(_ token: String)
- handleNotification(userInfo: [AnyHashable: Any])
- openNotificationSettings()
```

### SharedReelManager (@MainActor, ObservableObject)
```swift
@Published var reels: [SharedReel]
@Published var isUploading: Bool
@Published var uploadError: String?
@Published var lastUploadSuccess: Bool

Functions:
- handleSharedURL(_ url: URL) async -> Bool
- uploadReelToBackend(_ instagramURL: String) async -> Bool
- updateReelStatus(id:status:resultId:errorMessage:)
- markReelAsCompleted(factCheckId:)
```

## Models

### SharedReel (Identifiable, Codable)
```swift
struct SharedReel {
    let id: String
    let url: String
    let submittedAt: Date
    var status: FactCheckStatus
    var resultId: String?
    var errorMessage: String?
}
```

### FactCheckStatus (String, Codable)
```swift
enum FactCheckStatus {
    case pending
    case processing
    case completed
    case failed
}
```

## UserDefaults Keys

```
stored_user_id          → User's ID from backend
stored_username         → User's username
stored_device_token     → APNs device token
stored_shared_reels     → JSON array of SharedReel objects
```

## Backend API Contract

### 1. Register Device
```
POST /api/register-device
Content-Type: application/json

Request:
{
  "device_token": "abc123...",
  "platform": "ios"
}

Response:
{
  "success": true,
  "token_id": "..."
}
```

### 2. Submit Fact Check
```
POST /api/fact-check
Content-Type: application/json
Authorization: Bearer YOUR_TOKEN

Request:
{
  "url": "https://instagram.com/reel/...",
  "device_token": "abc123...",
  "submission_id": "uuid"
}

Response:
{
  "fact_check_id": "uuid",
  "status": "processing",
  "estimated_time": 90
}
```

### 3. Push Notification (Backend → APNs)
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
  "fact_check_id": "uuid-matching-submission_id"
}
```

## Color Palette (from ContentView.swift)

```swift
Color.brandTeal          // rgb(0, 0.75, 0.85)
Color.brandBlue          // rgb(0.15, 0.35, 0.95)
Color.backgroundLight    // rgb(0.97, 0.98, 1.0)
Color.brandGreen         // rgb(0.2, 0.75, 0.45)
Color.brandYellow        // rgb(0.98, 0.75, 0.15)
Color.brandRed           // rgb(0.95, 0.3, 0.3)
```

## Key Design Patterns

1. **Singleton Managers**: Shared across the app
2. **@Published Properties**: Automatic UI updates
3. **Swift Concurrency**: async/await for network calls
4. **NotificationCenter**: Cross-component communication
5. **UserDefaults**: Local persistence
6. **ObservableObject**: MVVM pattern
7. **@MainActor**: UI updates on main thread
8. **Environment Objects**: Dependency injection

## Integration Points

### Where New Code Integrates with Existing Code

```
informedApp.swift
├── Uses existing: UserManager
└── Adds: NotificationManager, SharedReelManager, AppDelegate

ContentView.swift
├── Uses existing: TabView structure
├── Keeps: HomeView, HistoryView
├── Adds: InstructionsView, SharedReelsView, SettingsView
└── Replaces: ProfileView → NotificationSettingsView

All Views
└── Have access to:
    ├── @EnvironmentObject UserManager
    ├── @EnvironmentObject NotificationManager
    └── @EnvironmentObject SharedReelManager
```

## Testing Entry Points

### Unit Tests (Can Add)
```swift
NotificationManagerTests
- testDeviceTokenSaving()
- testPermissionRequest()

SharedReelManagerTests
- testURLParsing()
- testStatusUpdates()
- testPersistence()
```

### UI Tests (Can Add)
```swift
InstructionsViewTests
- testInstructionStepsDisplay()
- testPermissionButtonAppears()

SharedReelsViewTests
- testEmptyState()
- testReelListDisplay()
- testStatusColors()
```

### Manual Tests
```bash
# URL handling
xcrun simctl openurl booted "factcheckapp://share?url=test"

# View console logs
# Use Console.app filtering for "Informed"
```

## Documentation Files

```
IMPLEMENTATION_GUIDE.md
└── Complete overview, setup, and flow explanations

ARCHITECTURE.md
└── Diagrams, data flow, system architecture

CHECKLIST.md
└── Step-by-step setup and verification checklist

QUICK_TEST_GUIDE.md
└── Fast reference for testing common scenarios

FIX_INFO_PLIST_ERROR.md
└── Solutions for the build error you mentioned

THIS_FILE.md
└── Project structure and file relationships
```

## Summary Statistics

- **New Swift Files**: 7
- **Modified Swift Files**: 2
- **Total Lines Added**: ~2,000
- **New Views**: 3
- **New Managers**: 2
- **New Models**: 2
- **API Endpoints**: 2
- **Documentation Files**: 5

## Next Steps Reference

1. Fix Info.plist build error → See `FIX_INFO_PLIST_ERROR.md`
2. Complete setup → See `CHECKLIST.md`
3. Test implementation → See `QUICK_TEST_GUIDE.md`
4. Understand architecture → See `ARCHITECTURE.md`
5. Full reference → See `IMPLEMENTATION_GUIDE.md`
