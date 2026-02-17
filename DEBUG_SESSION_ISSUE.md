# Debug: Session Expired Issue

## What to Check

When you see "Session expired" error in the Discover tab, run through this checklist:

### 1. Check the Console Logs

Look for these debug messages when you tap "Try Again" in Discover tab:

```
🔍 FeedViewModel attempting to load feed...
   UserManager.shared.currentUserId: [should show your user ID]
   UserManager.shared.currentSessionId: [should show your session ID]
   UserManager.shared.isAuthenticated: [should be true]
```

### Scenarios:

#### ✅ All Good (but backend not ready)
```
🔍 FeedViewModel attempting to load feed...
   UserManager.shared.currentUserId: abc-123-def
   UserManager.shared.currentSessionId: xyz-789-session
   UserManager.shared.isAuthenticated: true
✅ Attempting to fetch public feed for user: abc-123-def
❌ Error loading feed: [network error]
```
**Meaning:** Session is fine, but backend endpoints don't exist yet (expected)

#### ⚠️ Session ID Missing
```
🔍 FeedViewModel attempting to load feed...
   UserManager.shared.currentUserId: abc-123-def
   UserManager.shared.currentSessionId: nil
   UserManager.shared.isAuthenticated: true
⚠️ Cannot load feed: User ID exists but session ID is missing
```
**Meaning:** Session wasn't saved to Keychain properly. Need to log out and log back in.

#### ⚠️ Not Logged In
```
🔍 FeedViewModel attempting to load feed...
   UserManager.shared.currentUserId: nil
   UserManager.shared.currentSessionId: nil
   UserManager.shared.isAuthenticated: false
⚠️ Cannot load feed: User not logged in
```
**Meaning:** You're not logged in. Go to Account tab and log in.

## Quick Fix Steps

### If Session ID is Missing:

1. **Go to Account tab**
2. **Tap "Sign Out"**
3. **Log back in with your credentials**
4. **Go back to Discover tab**
5. **Tap "Try Again"**

The app now has a "Log Out & Log In Again" button that appears automatically when it detects a session issue.

### If Still Not Working:

The backend probably doesn't have the `/api/public-feed` endpoint yet. This is expected! The error message should now say:

> "Backend endpoints not ready. See BACKEND_URGENT_FIX.md"

This is the correct behavior until your backend team implements the endpoints.

## What the Updated Code Does

### 1. Better Debug Logging
- Shows exactly what session data exists
- Helps diagnose if it's a login issue or backend issue

### 2. Better Error Messages
- "Session expired. Please log out and log back in." → Session ID missing
- "Backend endpoints not ready." → Backend not implemented yet
- "Please log in to view the public feed" → Not logged in

### 3. Smart Error UI
- If session expired → Shows "Log Out & Log In Again" button
- If backend not ready → Shows "Try Again" button
- Automatically detects the issue type

## Expected Behavior

### Right Now (Backend Not Ready)
1. You should be logged in (check Account tab shows your username)
2. Console shows your userId and sessionId
3. Error message says "Backend endpoints not ready"
4. This is CORRECT! Just waiting for backend.

### After Backend Implementation
1. Tapping "Try Again" will load the public feed
2. You'll see reels from all users
3. Infinite scroll will work

## Test Your Login

1. **Go to Account tab**
2. **Check if you see:**
   - Your username at the top
   - Your user ID (first 8 characters)
   - Stats (Checked, Saved, Shared)
   
3. **If NOT logged in:**
   - You'll see a login button
   - Tap it and log in

4. **If logged in but session expired:**
   - Tap "Sign Out"
   - Tap "Sign In" again
   - Enter your credentials

5. **Go back to Discover tab and tap "Try Again"**

## Check Console for These Messages

Run the app in Xcode and look at the console output. You should see:

**When you open Discover tab:**
```
🔍 FeedViewModel attempting to load feed...
```

**This tells you:**
- Whether you're logged in
- Whether you have a valid session
- What the actual error is

Share these console logs if you need help debugging!

---

**Status After This Update:**
- ✅ Better error detection
- ✅ Detailed debug logging
- ✅ Smart error messages
- ✅ Auto-logout button when needed
- ✅ Clear guidance for user

The app will now tell you EXACTLY what's wrong and how to fix it!
