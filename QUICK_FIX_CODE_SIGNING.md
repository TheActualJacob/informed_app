# 🚀 QUICK FIX - Code Signing Error (2 Minutes)

## Current Error
```
"megastat.informed.InformedWidget" failed to launch
```

## Fix (In Xcode - 2 minutes)

### Step 1: Select Target
In Xcode Project Navigator:
- Click on **informed** (project root, blue icon)
- In the targets list, select **InformedWidgetExtension**

### Step 2: Add App Groups
- Go to **Signing & Capabilities** tab (top bar)
- Click **+ Capability** button
- Type "App Groups" and double-click to add
- Check the box for: **`group.com.jacob.informed`**

### Step 3: Verify
You should now see:
```
✅ Signing & Capabilities
   ├─ Signing
   │  ├─ Team: DJX5JN7CX8
   │  └─ Bundle ID: megastat.informed.InformedWidget
   └─ App Groups
      └─ ✅ group.com.jacob.informed
```

### Step 4: Clean & Build
- Press: **Shift + Cmd + K** (Clean)
- Press: **Cmd + B** (Build)

### Step 5: Run on Device
- Select your **iPhone 14 Pro or newer** as destination
- Press: **Cmd + R** (Run)

## Test
1. App should launch without errors ✅
2. Paste Instagram reel URL in search
3. **Look at top of screen**
4. Dynamic Island should appear within 1 second! 🎉

---

## If You Don't See App Groups Option

Alternative method:

1. In Xcode, find file: `InformedWidget/InformedWidget.entitlements`
2. If it doesn't exist in Project Navigator, add it:
   - Right-click **InformedWidget** folder
   - **Add Files to "informed"...**
   - Select `InformedWidget.entitlements`
   - Ensure **InformedWidgetExtension** target is checked
   - Click **Add**

3. Then in **Build Settings**:
   - Search for: "Code Signing Entitlements"
   - Set to: `InformedWidget/InformedWidget.entitlements`

---

## That's It!

The code signing error will be fixed and Dynamic Island will work!

**See `CURRENT_STATUS_AND_NEXT_STEPS.md` for full status.**
