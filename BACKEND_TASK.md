# Backend Task: Add Instagram Thumbnail Support

## 🎯 What You Need to Do

Add a `thumbnail_url` field to your fact-check API response that contains a direct image URL (not an Instagram page URL).

## Current Problem

You're returning:
```json
{
  "videoLink": "https://www.instagram.com/reel/ABC123/"
}
```

iOS tries to load this as an image → fails → shows grey box

## Required Fix

Return this instead:
```json
{
  "videoLink": "https://www.instagram.com/reel/ABC123/",
  "thumbnail_url": "https://instagram.fcdn.net/v/t51.2885-15/actual-image.jpg"
}
```

## Implementation (5 minutes)

### Option 1: Use yt-dlp (Recommended)

```bash
pip install yt-dlp
```

```python
import yt_dlp

def get_instagram_thumbnail(url):
    """Extract thumbnail from Instagram URL"""
    try:
        ydl_opts = {'quiet': True, 'no_warnings': True}
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            return info.get('thumbnail')
    except:
        return None

# In your fact-check endpoint:
thumbnail = get_instagram_thumbnail(instagram_url)

return {
    "title": ...,
    "videoLink": instagram_url,
    "thumbnail_url": thumbnail,  # ← ADD THIS
    "claim": ...,
    ...
}
```

### Option 2: Use instaloader

```bash
pip install instaloader
```

```python
import instaloader
from instaloader import Post

def get_instagram_thumbnail(url):
    """Extract thumbnail from Instagram URL"""
    try:
        L = instaloader.Instaloader()
        shortcode = url.split('/')[-2]  # Extract shortcode from URL
        post = Post.from_shortcode(L.context, shortcode)
        return post.url  # Returns thumbnail URL
    except:
        return None
```

## Testing

Test with a real Instagram reel URL:
```
https://www.instagram.com/reel/[any-reel-shortcode]/
```

Expected output:
```json
{
  "thumbnail_url": "https://instagram.fcdn.net/v/t51.2885-15/123456_n.jpg"
}
```

## Notes

- `thumbnail_url` can be `null` if extraction fails
- iOS will fall back to old behavior if field is missing
- This is a **non-breaking change**
- Works with yt-dlp's Instagram support (no API key needed)

## Questions?

See full technical details in: `INSTAGRAM_THUMBNAIL_ISSUE.md`
