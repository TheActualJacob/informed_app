# Quick Test Guide: TikTok Support

## Test URLs

### Instagram (Should work)
```
https://www.instagram.com/reel/C2xJ3kLMnPq/
https://instagram.com/reel/ABC123/
```

### TikTok (Should work - NEW!)
```
https://www.tiktok.com/@username/video/7234567890123456789
https://vm.tiktok.com/ZTdAbCdEf/
https://www.tiktok.com/t/ZTdAbCdEf/
```

### Invalid (Should reject)
```
https://youtube.com/watch?v=abc123
https://twitter.com/status/123
```

---

## Visual Checks

### ✅ Search Bar
- Placeholder says: "Paste Instagram Reel or TikTok URL..."
- Green border appears for both Instagram and TikTok URLs
- Red/no border for invalid URLs

### ✅ Platform Badges
- **Instagram videos:** Pink/orange gradient badge with camera icon
- **TikTok videos:** Black badge with music note icon
- Badge appears in top-right corner of thumbnail

### ✅ Icons
- Instagram cards show camera icon (camera.fill)
- TikTok cards show music note icon (music.note)

### ✅ Source Names
- Instagram reels say "Instagram"
- TikTok videos say "TikTok"

---

## Error Testing

### Test Backend Error Types

Send these from backend to see user-friendly messages:

```json
{ "error": "...", "error_type": "age_restricted" }
→ Shows: "This video is age-restricted and cannot be fact-checked"

{ "error": "...", "error_type": "private_account" }
→ Shows: "Cannot access videos from private accounts"

{ "error": "...", "error_type": "unavailable" }
→ Shows: "Video unavailable or region-locked"

{ "error": "...", "error_type": "invalid_url" }
→ Shows: "Invalid URL format. Please use Instagram Reel or TikTok video URLs"
```

---

## Backend Response Format

Backend should return:

```json
{
  "title": "Video Title",
  "claim": "The claim text",
  "verdict": "True",
  "platform": "tiktok",
  "thumbnail_url": "https://...",
  "error_type": null,
  // ... other fields
}
```

**Key fields:**
- `platform`: `"instagram"` or `"tiktok"`
- `error_type`: Error code if failed (optional)

---

## Quick Test Procedure

1. **Open app** → Home tab
2. **Paste Instagram URL** → Should show green border, fact-check works
3. **Paste TikTok URL** → Should show green border, fact-check works
4. **Check thumbnail** → Should see platform badge (pink for IG, black for TikTok)
5. **Check icon** → Camera for Instagram, music note for TikTok
6. **Try invalid URL** → Should not show green border

---

## Files to Check for Debugging

- `SearchBar.swift` - URL validation
- `LinkPreviewView.swift` - Platform badge rendering
- `FactCheckModels.swift` - Platform detection logic
- `ErrorHelpers.swift` - Error message mapping

---

**All features implemented and tested ✅**
