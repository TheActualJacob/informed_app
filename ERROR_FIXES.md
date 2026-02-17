# Error Fixes - February 16, 2026

## Issue: calculateCredibilityScore Method Not Found

### Problem
Several files were calling `calculateCredibilityScore()` as a method on HomeViewModel instances, causing compilation errors:
- `SharedReelManager.swift:192` - `viewModel.calculateCredibilityScore(...)`
- `SharedReelManager.swift:375` - `homeViewModel.calculateCredibilityScore(...)`
- `AppDelegate.swift:156` - `homeViewModel.calculateCredibilityScore(...)`

### Root Cause
The `calculateCredibilityScore` function exists as a **global utility function** in `Models/FactCheckModels.swift`, not as a method on HomeViewModel. While we added it to HomeViewModel for consistency, the Xcode indexer was not recognizing it properly.

### Solution
Changed all calls to use the global function directly instead of calling it on HomeViewModel instances:

```swift
// Before
credibilityScore: viewModel.calculateCredibilityScore(from: rating)

// After
credibilityScore: calculateCredibilityScore(from: rating)
```

### Files Modified
1. ✅ `SharedReelManager.swift` (2 locations fixed)
2. ✅ `AppDelegate.swift` (1 location fixed)

### Result
- ✅ Zero compilation errors
- ✅ All files compile successfully
- ✅ Global function is properly accessible from all locations

### Note
The `calculateCredibilityScore` function is defined in `Models/FactCheckModels.swift` as a global utility function:

```swift
func calculateCredibilityScore(from rating: String) -> Double {
    let numericString = rating.replacingOccurrences(of: "%", with: "")
    if let percentage = Double(numericString) {
        return percentage / 100.0
    }
    return 0.5 // Default to 50% if parsing fails
}
```

This is the correct approach for a simple utility function that doesn't require instance state.
