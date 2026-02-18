# Dynamic Island Architecture - Visual Guide

## 🏗️ Current Architecture (BROKEN)

```
┌─────────────────────────────────────────────────────────┐
│                    informed.app                         │
│                                                         │
│  ┌────────────────────────────────────────────────┐   │
│  │ Main App Target: informed                      │   │
│  │                                                 │   │
│  │  ┌──────────────────────────────────────┐     │   │
│  │  │ informedApp.swift                    │     │   │
│  │  │ @main ← Entry Point                  │     │   │
│  │  └──────────────────────────────────────┘     │   │
│  │                                                 │   │
│  │  ┌──────────────────────────────────────┐     │   │
│  │  │ ReelProcessingActivity.swift         │     │   │
│  │  │ ✅ ActivityAttributes defined        │     │   │
│  │  └──────────────────────────────────────┘     │   │
│  │                                                 │   │
│  │  ┌──────────────────────────────────────┐     │   │
│  │  │ ReelProcessingLiveActivity.swift     │     │   │
│  │  │ ❌ Widget UI (WRONG TARGET!)         │     │   │
│  │  └──────────────────────────────────────┘     │   │
│  │                                                 │   │
│  │  Activity.request() ────────────────────────┐ │   │
│  └─────────────────────────────────────────────┼─┘   │
└────────────────────────────────────────────────┼──────┘
                                                  │
                                                  ↓
                              ┌───────────────────────────────┐
                              │ iOS System: ActivityKit       │
                              │ ✅ Activity registered        │
                              │ ⚙️  Status: Active            │
                              └───────────────────────────────┘
                                                  │
                                                  ↓
                              ┌───────────────────────────────┐
                              │ iOS: "Looking for Widget      │
                              │       Extension to render UI" │
                              │ 🔍 Searching...               │
                              └───────────────────────────────┘
                                                  │
                                                  ↓
                              ┌───────────────────────────────┐
                              │ ❌ ERROR: No Widget Extension │
                              │            Found!             │
                              └───────────────────────────────┘
                                                  │
                                                  ↓
                           ╔══════════════════════════════════╗
                           ║  Dynamic Island: BLANK/NOTHING   ║
                           ║  (UI cannot render)              ║
                           ╚══════════════════════════════════╝
```

---

## 🏗️ Correct Architecture (WORKING)

```
┌─────────────────────────────────────────────────────────────────┐
│                       informed.app                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐     │
│  │ Main App Target: informed                             │     │
│  │                                                        │     │
│  │  ┌─────────────────────────────────────────────┐     │     │
│  │  │ informedApp.swift                           │     │     │
│  │  │ @main ← Entry Point                         │     │     │
│  │  └─────────────────────────────────────────────┘     │     │
│  │                                                        │     │
│  │  ┌─────────────────────────────────────────────┐     │     │
│  │  │ ReelProcessingActivity.swift (SHARED)       │     │     │
│  │  │ ✅ ActivityAttributes defined               │◀────┼──┐  │
│  │  └─────────────────────────────────────────────┘     │  │  │
│  │                                                        │  │  │
│  │  Activity.request() ──────────────────────────────┐  │  │  │
│  └───────────────────────────────────────────────────┼──┘  │  │
│                                                       │     │  │
│  ┌───────────────────────────────────────────────────┼─────┼──┤
│  │ Widget Extension Target: InformedWidget.appex    │     │  │
│  │                                                    │     │  │
│  │  ┌─────────────────────────────────────────────┐ │     │  │
│  │  │ InformedWidgetBundle.swift                  │ │     │  │
│  │  │ @main ← Widget Entry Point                  │ │     │  │
│  │  └─────────────────────────────────────────────┘ │     │  │
│  │                                                    │     │  │
│  │  ┌─────────────────────────────────────────────┐ │     │  │
│  │  │ ReelProcessingLiveActivity.swift            │ │     │  │
│  │  │ ✅ Widget UI (CORRECT TARGET!)              │ │     │  │
│  │  └─────────────────────────────────────────────┘ │     │  │
│  │                                                    │     │  │
│  │  ┌─────────────────────────────────────────────┐ │     │  │
│  │  │ ReelProcessingActivity.swift (SHARED)       │◀┼─────┘  │
│  │  │ ✅ ActivityAttributes visible here too      │ │        │
│  │  └─────────────────────────────────────────────┘ │        │
│  │                                                    │        │
│  └────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ↓
            ┌───────────────────────────────────┐
            │ iOS System: ActivityKit           │
            │ ✅ Activity registered            │
            │ ⚙️  Status: Active                │
            └───────────────────────────────────┘
                            │
                            ↓
            ┌───────────────────────────────────┐
            │ iOS: "Looking for Widget          │
            │       Extension to render UI"     │
            │ 🔍 Searching...                   │
            └───────────────────────────────────┘
                            │
                            ↓
            ┌───────────────────────────────────┐
            │ ✅ FOUND: InformedWidget.appex    │
            │    Loading Live Activity UI...    │
            └───────────────────────────────────┘
                            │
                            ↓
            ┌───────────────────────────────────┐
            │ Widget Process Starts             │
            │ ├─ InformedWidgetBundle (@main)   │
            │ └─ ReelProcessingLiveActivity     │
            └───────────────────────────────────┘
                            │
                            ↓
         ╔════════════════════════════════════════╗
         ║   Dynamic Island: RENDERS! ✅          ║
         ║                                        ║
         ║   [●]  Fact-Checking  [○ 45%]        ║
         ║                                        ║
         ║   (Compact view visible)               ║
         ╚════════════════════════════════════════╝
```

---

## 🔄 Data Flow

### Starting an Activity

```
App Code (informed target)
    │
    │  Activity<ReelProcessingActivityAttributes>.request()
    │
    ↓
ActivityKit System Service
    │
    ├──→ Stores activity state
    ├──→ Manages lifecycle
    └──→ Notifies Widget Extension
            │
            ↓
    Widget Extension Process (InformedWidget.appex)
            │
            ├──→ InformedWidgetBundle launches
            ├──→ ReelProcessingLiveActivity.body called
            └──→ Renders UI to Dynamic Island
                    │
                    ↓
            ╔═══════════════════╗
            ║  Dynamic Island   ║
            ║   [Visible! ✨]   ║
            ╚═══════════════════╝
```

### Updating an Activity

```
App Code (informed target)
    │
    │  activity.update(using: newState)
    │
    ↓
ActivityKit System Service
    │
    ├──→ Updates stored state
    └──→ Sends to Widget Extension
            │
            ↓
    Widget Extension (InformedWidget.appex)
            │
            ├──→ Receives new ContentState
            ├──→ Re-renders UI
            └──→ Updates Dynamic Island
                    │
                    ↓
            ╔═══════════════════╗
            ║  Dynamic Island   ║
            ║   [○ 75%] ✨      ║
            ╚═══════════════════╝
```

---

## 📦 File Organization

### informed (Main App)
```
informed/
├── informedApp.swift (@main)
├── Models/
│   └── ReelProcessingActivity.swift [✅ Shared]
├── Extensions/
│   └── ColorPalette.swift [✅ Shared]
├── Utilities/
│   └── HapticManager.swift [✅ Shared]
└── Views/
    ├── HomeView.swift
    ├── FeedView.swift
    └── (other app views)
```

### InformedWidget.appex (Widget Extension)
```
InformedWidget/
├── InformedWidgetBundle.swift (@main for widget)
├── ReelProcessingLiveActivity.swift [✅ Widget UI]
└── (References shared files from main app)
```

---

## 🎯 Key Concepts

### Two Separate Processes

| Process | Entry Point | Purpose | Can Access |
|---------|-------------|---------|------------|
| **Main App** | `informedApp.swift` `@main` | User interaction, business logic | Full app code |
| **Widget Extension** | `InformedWidgetBundle.swift` `@main` | Render Live Activity UI | Only shared files |

### Shared Code

Files with **both** target memberships are compiled into **both** binaries:
- `ReelProcessingActivity.swift` - Activity model (needed by both)
- `ColorPalette.swift` - Colors used in UI (needed by widget)
- `HapticManager.swift` - Haptic feedback (used by activity manager)

### Communication

```
Main App ←→ ActivityKit (iOS) ←→ Widget Extension
```

- App **starts/updates/ends** activities via ActivityKit API
- Widget Extension **renders UI** based on activity state
- They don't directly communicate - iOS mediates

---

## ✅ Why This Fixes It

**Before**: Widget UI code in main app target → iOS can't find it → No rendering  
**After**: Widget UI code in widget extension → iOS finds and loads it → Rendering works!

The Live Activity **data model** works in the main app (you see "Activity started" logs).  
The Live Activity **UI rendering** requires the widget extension.

**Both are required. One without the other doesn't work.**

---

## 🚀 Implementation

Follow: **QUICK_START_FIX_DYNAMIC_ISLAND.md** (10 minutes)

This diagram shows why it's the only solution.
