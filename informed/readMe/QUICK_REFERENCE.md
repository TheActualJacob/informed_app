# Informed App - Quick Reference Guide

## 📁 File Organization

### Where to Find Things

| What you need | Where to look |
|--------------|---------------|
| Color definitions | `Extensions/ColorPalette.swift` |
| Spacing, fonts, animations | `Extensions/Theme.swift` |
| Fact-check data models | `Models/FactCheckModels.swift` |
| Feed business logic | `ViewModels/HomeViewModel.swift` |
| Account stats logic | `ViewModels/AccountViewModel.swift` |
| Main feed UI | `Views/HomeView.swift` |
| Detail page UI | `Views/FactDetailView.swift` |
| Account/profile UI | `Views/AccountView.swift` |
| Search bar | `Components/SearchBar.swift` |
| Fact card | `Components/FactResultCard.swift` |
| Loading banner | `Components/ProcessingBanner.swift` |
| Error handling | `Components/ErrorView.swift` |
| API calls | `Services/NetworkService.swift` |
| Data persistence | `Services/PersistenceService.swift` |
| Haptic feedback | `Utilities/HapticManager.swift` |
| String helpers | `Utilities/StringHelpers.swift` |

## 🎨 Using the Design System

### Colors
```swift
// Brand colors
.foregroundColor(.brandBlue)      // Primary brand color
.foregroundColor(.brandTeal)      // Secondary accent
.foregroundColor(.brandGreen)     // Success/verified
.foregroundColor(.brandYellow)    // Warning/debated
.foregroundColor(.brandRed)       // Error/false

// Backgrounds
.background(Color.backgroundLight)  // Main background
.background(Color.cardBackground)   // Cards/containers

// Gradients
.background(Color.brandGradient())
```

### Spacing
```swift
.padding(Theme.Spacing.xs)   // 4pt
.padding(Theme.Spacing.sm)   // 8pt
.padding(Theme.Spacing.md)   // 12pt
.padding(Theme.Spacing.lg)   // 16pt
.padding(Theme.Spacing.xl)   // 20pt
.padding(Theme.Spacing.xxl)  // 24pt
```

### Corner Radius
```swift
.cornerRadius(Theme.CornerRadius.sm)   // 8
.cornerRadius(Theme.CornerRadius.md)   // 12
.cornerRadius(Theme.CornerRadius.lg)   // 16
.cornerRadius(Theme.CornerRadius.xl)   // 24
```

### Animations
```swift
.animation(Theme.Animation.spring, value: someValue)
.animation(Theme.Animation.smooth, value: someValue)
.animation(Theme.Animation.quick, value: someValue)
```

### Shadows
```swift
.shadow(
    color: Theme.Shadow.card(for: colorScheme),
    radius: Theme.Shadow.md,
    y: 4
)
```

## 🔌 Using Services

### Network Calls
```swift
// Fact check
let data = try await NetworkService.shared.performFactCheck(
    link: url,
    userId: userId,
    sessionId: sessionId
)

// User creation
let user = try await NetworkService.shared.createUser(
    username: username,
    email: email,
    password: password
)

// Login
let response = try await NetworkService.shared.loginUser(
    email: email,
    password: password
)

// Register device for notifications
try await NetworkService.shared.registerDevice(token: deviceToken)
```

### Error Handling
```swift
do {
    let data = try await NetworkService.shared.performFactCheck(...)
    // Handle success
} catch let networkError as NetworkError {
    // Use networkError.errorDescription for user-friendly message
    errorMessage = networkError.errorDescription
}
```

### Data Persistence
```swift
// Save fact check
PersistenceService.shared.saveFactCheck(item)

// Get history
let history = PersistenceService.shared.getFactCheckHistory()

// Clear history
PersistenceService.shared.clearHistory()

// Save for later
PersistenceService.shared.saveFactCheckForLater(item)

// Get saved items
let saved = PersistenceService.shared.getSavedFactChecks()

// Check if saved
let isSaved = PersistenceService.shared.isFactCheckSaved(item)

// Stats
PersistenceService.shared.incrementSharedCount()
let count = PersistenceService.shared.getSharedCount()
```

### Haptic Feedback
```swift
// Impact feedback
HapticManager.lightImpact()    // Light tap
HapticManager.mediumImpact()   // Medium tap
HapticManager.heavyImpact()    // Heavy tap

// Notification feedback
HapticManager.success()        // Success action
HapticManager.warning()        // Warning
HapticManager.error()          // Error

// Selection feedback
HapticManager.selection()      // Picker/selector change
```

## 🧩 Using Components

### Search Bar
```swift
@State private var searchText = ""
@FocusState private var isFocused: Bool

SearchBarView(text: $searchText, isFocused: $isFocused)
```

### Fact Result Card
```swift
ForEach(items) { item in
    NavigationLink(destination: FactDetailView(item: item)) {
        FactResultCard(item: item)
    }
    .buttonStyle(PlainButtonStyle())
}
```

### Processing Banner
```swift
if let processingLink = viewModel.processingLink {
    ProcessingBanner(
        link: processingLink,
        thumbnailURL: viewModel.processingThumbnailURL
    )
}
```

### Error View
```swift
if let error = viewModel.error {
    ErrorView(error: error) {
        viewModel.retry()
    }
}
```

### Error Banner
```swift
if let errorMessage = viewModel.errorMessage {
    ErrorBanner(message: errorMessage) {
        viewModel.errorMessage = nil
    }
}
```

### Empty State
```swift
EmptyStateView(
    icon: "tray.fill",
    title: "No Results",
    message: "Your content will appear here",
    actionTitle: "Reload",
    action: { reload() }
)
```

### Donut Chart
```swift
DonutChart(
    score: item.credibilityScore,
    color: item.credibilityLevel.color
)
```

## 📱 Common Patterns

### View with ViewModel
```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()
    
    var body: some View {
        // Use viewModel.property
    }
}
```

### Loading States
```swift
ZStack {
    if viewModel.isLoading {
        ProgressView()
    } else {
        ContentView()
    }
}

// Or with redacted
VStack {
    Text(viewModel.data)
}
.redacted(reason: viewModel.isLoading ? .placeholder : [])
```

### NavigationLink with Haptics
```swift
NavigationLink(destination: DetailView()) {
    CardView()
}
.onTapGesture {
    HapticManager.lightImpact()
}
```

### Async Loading Pattern
```swift
.task {
    await viewModel.loadData()
}

// Or in onAppear
.onAppear {
    Task {
        await viewModel.loadData()
    }
}
```

## 🎯 Best Practices

### DO ✅
- Use Theme constants for spacing, colors, etc.
- Add haptic feedback to interactive elements
- Handle errors with NetworkError
- Save important data with PersistenceService
- Use loading states (skeleton or progress)
- Add navigation haptics

### DON'T ❌
- Hard-code colors or spacing values
- Use `UIImpactFeedbackGenerator` directly
- Access UserDefaults directly
- Ignore error states
- Skip loading states
- Mix business logic with UI code

## 🔄 Migration Checklist

Moving code to the new structure? Use this checklist:

- [ ] Extract hard-coded colors to Theme/ColorPalette
- [ ] Replace spacing numbers with Theme.Spacing
- [ ] Move business logic to ViewModels
- [ ] Replace direct API calls with NetworkService
- [ ] Replace UserDefaults with PersistenceService
- [ ] Add haptic feedback to buttons/taps
- [ ] Add loading states
- [ ] Add error handling
- [ ] Use reusable components where possible
- [ ] Test in both light and dark mode

## 💡 Tips

1. **Command+Shift+O**: Quick open files by name
2. **Cmd+Click** on a component to see its definition
3. Check `Theme.swift` before creating new spacing/animation values
4. Look in `Components/` before creating a new reusable view
5. Use `ColorPalette.swift` for all color needs

## 🐛 Troubleshooting

**Import errors**: Make sure you import the right modules
**Color not found**: Check `Extensions/ColorPalette.swift`
**Theme constant not found**: Check `Extensions/Theme.swift`
**Network call fails**: Check `Services/NetworkService.swift` error handling
**Data not persisting**: Check `Services/PersistenceService.swift` implementation

---

**Need more help?** Check the full `REFACTORING_SUMMARY.md` for detailed information.
