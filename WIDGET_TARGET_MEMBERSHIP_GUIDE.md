# Files That Need Target Membership in BOTH App and Widget Extension

After creating the Widget Extension target, you need to ensure certain files are accessible to BOTH targets.

## ✅ Files to Add to BOTH Targets

### 1. ReelProcessingActivity.swift
**Path**: `informed/Models/ReelProcessingActivity.swift`  
**Reason**: Contains `ActivityAttributes` and manager needed by both app and widget  
**Target Membership**: ✅ informed, ✅ InformedWidget

### 2. ColorPalette.swift
**Path**: `informed/Extensions/ColorPalette.swift`  
**Reason**: Widget UI references `.brandBlue`, `.brandGreen`, `.brandRed`, `.cardBackground`  
**Target Membership**: ✅ informed, ✅ InformedWidget

### 3. HapticManager.swift  
**Path**: `informed/Utilities/HapticManager.swift`  
**Reason**: Activity manager triggers haptics (lightImpact, successImpact, errorImpact)  
**Target Membership**: ✅ informed, ✅ InformedWidget

## ✅ Files ONLY in Widget Extension

### 1. ReelProcessingLiveActivity.swift
**Path**: `informed/Views/ReelProcessingLiveActivity.swift` → **MOVE TO** `InformedWidget/`  
**Reason**: The Live Activity UI widget - only runs in widget extension context  
**Target Membership**: ❌ informed, ✅ InformedWidget  
**Action**: **Remove from main app, add to widget extension**

### 2. InformedWidgetBundle.swift
**Path**: `InformedWidget/InformedWidgetBundle.swift` (auto-created)  
**Reason**: Entry point for widget extension with `@main` attribute  
**Target Membership**: ❌ informed, ✅ InformedWidget

## 🔧 How to Set Target Membership in Xcode

1. Select the file in Project Navigator
2. Open **File Inspector** (right sidebar, first icon)
3. Find **Target Membership** section
4. Check/uncheck the appropriate targets

## 📊 Target Membership Summary

| File | informed | InformedWidget |
|------|----------|----------------|
| ReelProcessingActivity.swift | ✅ | ✅ |
| ColorPalette.swift | ✅ | ✅ |
| HapticManager.swift | ✅ | ✅ |
| ReelProcessingLiveActivity.swift | ❌ | ✅ |
| InformedWidgetBundle.swift | ❌ | ✅ |
| All other app files | ✅ | ❌ |

## ⚠️ Common Mistakes

### Mistake 1: ReelProcessingActivity.swift only in main app
**Symptom**: Widget extension build fails - "Cannot find type 'ReelProcessingActivityAttributes'"  
**Fix**: Add to InformedWidget target membership

### Mistake 2: ColorPalette.swift only in main app
**Symptom**: Widget extension build fails - "Cannot find 'brandBlue' in scope"  
**Fix**: Add to InformedWidget target membership

### Mistake 3: ReelProcessingLiveActivity.swift in BOTH targets
**Symptom**: Build fails - "'main' attribute can only apply to one type in a module"  
**Fix**: Remove from informed target, keep only in InformedWidget

### Mistake 4: HapticManager.swift only in main app
**Symptom**: Widget extension build fails - "Cannot find 'HapticManager' in scope"  
**Fix**: Add to InformedWidget target membership

## 🎯 Verification Checklist

After setting target membership, verify:

- [ ] Open `ReelProcessingActivity.swift` → File Inspector shows both targets checked
- [ ] Open `ColorPalette.swift` → File Inspector shows both targets checked
- [ ] Open `HapticManager.swift` → File Inspector shows both targets checked
- [ ] Open `ReelProcessingLiveActivity.swift` → File Inspector shows ONLY InformedWidget checked
- [ ] Select **InformedWidget** scheme → Build succeeds
- [ ] Select **informed** scheme → Build succeeds
- [ ] No "@main attribute" errors
- [ ] No "Cannot find type" errors

## 🚀 Build Order

1. Clean Build Folder (Shift+Cmd+K)
2. Build **InformedWidget** scheme first - verifies widget extension compiles
3. Build **informed** scheme - embeds the widget extension
4. Run **informed** scheme on physical device
5. Test Live Activity functionality

---

**Important**: The widget extension is a separate binary that runs in its own process. It's embedded in your main app bundle but executes independently. That's why ActivityAttributes and shared resources must have membership in both targets.
