# Instagram Thumbnail Issue - CRITICAL FIX NEEDED

## 🔴 Problem Summary

Instagram previews show as **grey boxes** instead of actual thumbnails because the backend is returning the Instagram video URL in the `videoLink` field, and the iOS app is trying to use that as a thumbnail image URL.

## Root Cause Analysis

### Current Flow (BROKEN):

1. **Backend returns** `FactCheckData` with:
   ```json
   {
     "videoLink": "https://www.instagram.com/reel/..."
   }
   ```

2. **iOS app creates thumbnailURL** from videoLink:
   ```swift
   // In HomeViewModel.swift line 107
   thumbnailURL: URL(string: factCheckData.videoLink)
   
   // In AppDelegate.swift line 155
   thumbnailURL: URL(string: factCheckData.videoLink)
   ```

3. **AsyncImage tries to load** the Instagram URL as an image:
   ```swift
   // In LinkPreviewView.swift line 14
   AsyncImage(url: item.thumbnailURL) { phase in
       if let image = phase.image {
           image.resizable().aspectRatio(contentMode: .fill)
       } else {
           // ❌ THIS HAPPENS - Instagram URLs don't load as images
           Rectangle().fill(Color.secondary.opacity(0.2))
       }
   }
   ```

4. **Result**: Grey box appears because Instagram video URLs cannot be loaded as images by AsyncImage

## Why Instagram URLs Don't Work as Images

- Instagram video URLs like `https://www.instagram.com/reel/ABC123/` return HTML pages, not image data
- AsyncImage expects direct image URLs (`.jpg`, `.png`, etc.)
- Instagram requires OAuth authentication and special API calls to get thumbnail images
- Direct linking to Instagram media is intentionally blocked by Instagram's CDN

## ✅ Required Backend Changes

### Option 1: Extract Thumbnail from Instagram (RECOMMENDED)

Your backend needs to extract the actual thumbnail image URL when processing Instagram reels:

1. **Download the Instagram reel metadata** (you may already be doing this)
2. **Extract the thumbnail URL** from the metadata
3. **Return the thumbnail URL** in a new field

**Add new field to backend response:**
```json
{
  "title": "...",
  "description": "...",
  "date": "...",
  "videoLink": "https://www.instagram.com/reel/ABC123/",
  "thumbnailUrl": "https://instagram.fcdn.net/v/t51.2885-15/...",  // ⬅️ ADD THIS
  "claim": "...",
  "verdict": "...",
  ...
}
```

**Backend implementation options:**
- Use `yt-dlp` library (supports Instagram): `yt-dlp --get-thumbnail <instagram-url>`
- Use `instaloader` library: Gets thumbnail URLs from Instagram reels
- Use Instagram's oEmbed API: `https://graph.facebook.com/v12.0/instagram_oembed?url=...&access_token=...`
- Parse Instagram page HTML for `og:image` meta tag

### Option 2: Generate Thumbnail from Video (ALTERNATIVE)

If extracting from Instagram is too complex:

1. **Download the video** (you may already be doing this for transcription)
2. **Extract first frame** as thumbnail using ffmpeg
3. **Upload thumbnail** to your own CDN/storage
4. **Return your hosted thumbnail URL**

```bash
# Example with ffmpeg
ffmpeg -i video.mp4 -ss 00:00:01 -vframes 1 thumbnail.jpg
```

### Option 3: Use Placeholder (TEMPORARY FALLBACK)

For non-Instagram URLs or when extraction fails:

1. **Generate a placeholder** image with the video title
2. **Use a default thumbnail** image
3. **Return null** and let iOS handle it gracefully

## 📝 Required iOS Changes (Already Prepared)

### Update FactCheckData Model

```swift
struct FactCheckData: Codable {
    let title: String
    let description: String
    let date: String
    let videoLink: String
    let thumbnailUrl: String?  // ⬅️ ADD THIS (optional in case of failure)
    let claim: String
    let verdict: String
    let claimAccuracyRating: String
    let explanation: String
    let summary: String
    let sources: [String]
    
    enum CodingKeys: String, CodingKey {
        case title, description, date, videoLink, claim, verdict, explanation, summary, sources
        case claimAccuracyRating = "claim_accuracy_rating"
        case thumbnailUrl = "thumbnail_url"  // ⬅️ ADD THIS
    }
}
```

### Update FactCheckItem Creation

```swift
// Use thumbnailUrl if available, fallback to videoLink for non-Instagram
let thumbnailString = factCheckData.thumbnailUrl ?? factCheckData.videoLink
let newItem = FactCheckItem(
    // ...
    thumbnailURL: URL(string: thumbnailString),
    // ...
)
```

## 🎯 Recommendation

**Option 1 is STRONGLY RECOMMENDED** because:
- ✅ Most accurate - shows actual Instagram thumbnail
- ✅ Fast loading - no video download needed
- ✅ Better UX - users see familiar Instagram preview
- ✅ Lower bandwidth - images are much smaller than videos

## 📋 Backend Task Checklist

Ask your backend developer to:

- [ ] Add `thumbnail_url` field to fact-check response JSON
- [ ] Implement Instagram thumbnail extraction (using yt-dlp, instaloader, or Instagram API)
- [ ] Test with multiple Instagram reel URLs
- [ ] Handle edge cases (private accounts, deleted videos, etc.)
- [ ] Return `null` or fallback URL when thumbnail extraction fails
- [ ] Update API documentation with new field

## 🧪 Testing URLs

Test with these Instagram reels to verify thumbnail extraction:
- Public reel example: `https://www.instagram.com/reel/C2xJ3...` (get real one)
- Private account reel (should handle gracefully)
- Deleted reel (should handle gracefully)

## 📚 Backend Library Recommendations

### Python (if using Flask/FastAPI):
```python
# Using yt-dlp (EASIEST)
import yt_dlp

def get_instagram_thumbnail(url):
    ydl_opts = {
        'quiet': True,
        'no_warnings': True,
        'extract_flat': True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return info.get('thumbnail')

# Using instaloader (MORE FEATURES)
import instaloader
L = instaloader.Instaloader()
post = instaloader.Post.from_shortcode(L.context, "ABC123")
thumbnail_url = post.url
```

### Node.js (if using Express):
```javascript
// Using instagram-url-direct
const { instagramGetUrl } = require('instagram-url-direct');

async function getInstagramThumbnail(url) {
  const result = await instagramGetUrl(url);
  return result.thumb;
}
```

## Current Files That Need Backend Response

These iOS files are waiting for the `thumbnail_url` field:

1. `/informed/Requests.swift` - Line 50: FactCheckData model
2. `/informed/ViewModels/HomeViewModel.swift` - Line 107: Creates FactCheckItem
3. `/informed/AppDelegate.swift` - Line 155: Creates FactCheckItem from notification
4. `/informed/SharedReelManager.swift` - Line 368: Creates FactCheckItem

## Impact

**Without this fix:**
- ❌ All Instagram reels show grey box previews
- ❌ Poor user experience
- ❌ Feed looks broken/unfinished
- ❌ Users can't identify which video was fact-checked

**With this fix:**
- ✅ Beautiful Instagram thumbnail previews
- ✅ Professional, polished appearance
- ✅ Users can see video at a glance
- ✅ Consistent with Instagram's own UI

---

## Summary for Backend Developer

**YOU NEED TO ADD: A `thumbnail_url` field to your fact-check API response that contains a direct link to an image file (not an Instagram page URL).**

The quickest solution is to use `yt-dlp` library to extract the thumbnail when you process the Instagram URL.
