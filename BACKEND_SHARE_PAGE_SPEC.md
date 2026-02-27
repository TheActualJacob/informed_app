# Backend Share Page — Complete Implementation Spec

## Overview

When a user taps **"Share This Fact Check"** in the iOS app, the app constructs:

```
https://informed-production.up.railway.app/share/{uniqueID}
```

This URL is shared via the iOS share sheet (iMessage, Twitter, Instagram story, etc.).
The backend must serve a fully server-rendered HTML page at that route — **no JavaScript required for content** — so that Open Graph scrapers (iMessage, Slack, Twitter previews) read the correct metadata.

---

## 1. Route to Add

```
GET /share/<unique_id>
```

- **Method:** `GET`
- **Param:** `unique_id` — the `uniqueID` column from your `fact_checks` table (same ID the app already uses everywhere)
- **Returns:** `text/html` — a fully server-rendered HTML page
- **Error (404):** Return a simple "Fact check not found" HTML page (same shell, just a message in the centre)

### Python (Flask) Example

```python
@app.route('/share/<unique_id>', methods=['GET'])
def share_page(unique_id):
    conn = get_db_connection()
    c = conn.cursor()
    c.execute('''
        SELECT uniqueID, title, description, summary, claim, is_factual,
               confidence, thumbnailUrl, videoLink, checked_at,
               uploaded_by, platform, aiGenerated, aiProbability,
               claims_json
        FROM fact_checks
        WHERE uniqueID = ?
    ''', (unique_id,))
    row = c.fetchone()
    conn.close()

    if row is None:
        return render_share_not_found(), 404

    reel = dict(row)
    
    # Parse claims_json if you store multi-claim data as JSON
    import json
    claims = []
    if reel.get('claims_json'):
        try:
            claims = json.loads(reel['claims_json'])
        except Exception:
            pass
    # Fallback to single claim from flat columns
    if not claims:
        claims = [{
            'claim': reel.get('claim', ''),
            'verdict': reel.get('is_factual', ''),
            'claimAccuracyRating': reel.get('confidence', '50%'),
            'summary': reel.get('summary', ''),
        }]

    return render_share_page(reel, claims), 200, {'Content-Type': 'text/html; charset=utf-8'}
```

---

## 2. Data You Need From the Database

| Field | DB Column | Used For |
|---|---|---|
| Title | `title` | Hero heading, OG title |
| Summary | `summary` | Subheading card, OG description |
| Thumbnail URL | `thumbnailUrl` | Hero image, OG image |
| Original video link | `videoLink` | "View original" button |
| Platform | `platform` | Platform badge (Instagram/TikTok/etc.) |
| Checked at | `checked_at` | "Checked X ago" timestamp |
| Uploaded by username | `uploaded_by` → join users table for username | "Shared by @user" |
| Claims array | `claims_json` (or flat columns) | Claim verdict cards |
| — each claim: `claim` | | Claim text |
| — each claim: `verdict` | | True/False/Misleading label |
| — each claim: `claimAccuracyRating` | | Accuracy % for progress bar |
| — each claim: `summary` | | One-line summary per claim |
| AI generated | `aiGenerated` | AI badge |
| AI probability | `aiProbability` | AI confidence % |

> **DO NOT expose:** `explanation` or `sources` — these are intentionally hidden to drive app downloads.

---

## 3. Credibility Colour Logic

Use the same thresholds the iOS app uses:

```python
def credibility_level(rating_str):
    """rating_str is like '85%' or '0.85'"""
    s = rating_str.replace('%', '').strip()
    try:
        score = float(s) / 100 if float(s) > 1 else float(s)
    except ValueError:
        score = 0.5
    if score >= 0.8:
        return 'high'    # green  #22c55e
    elif score >= 0.5:
        return 'medium'  # yellow #eab308
    else:
        return 'low'     # red    #ef4444

LEVEL_COLORS = {
    'high':   {'bg': '#dcfce7', 'text': '#16a34a', 'bar': '#22c55e', 'label': 'Verified'},
    'medium': {'bg': '#fef9c3', 'text': '#ca8a04', 'bar': '#eab308', 'label': 'Debated'},
    'low':    {'bg': '#fee2e2', 'text': '#dc2626', 'bar': '#ef4444', 'label': 'Misleading'},
}
```

---

## 4. Open Graph Tags (Required for Rich Previews)

Put these in the `<head>`. iMessage, Twitter, Slack, and WhatsApp all use them:

```html
<meta property="og:title"       content="{title}" />
<meta property="og:description" content="{first_claim_summary}" />
<meta property="og:image"       content="{thumbnailUrl}" />
<meta property="og:url"         content="https://informed-production.up.railway.app/share/{uniqueID}" />
<meta property="og:type"        content="article" />
<meta name="twitter:card"       content="summary_large_image" />
<meta name="twitter:title"      content="{title}" />
<meta name="twitter:description" content="{first_claim_summary}" />
<meta name="twitter:image"      content="{thumbnailUrl}" />
```

---

## 5. Complete HTML Template

Copy-paste this exactly. Replace `{{ variable }}` with your template engine syntax (Jinja2, etc.). The styles are self-contained — no external CSS frameworks needed.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0" />
  <title>{{ title }} — Informed</title>

  <!-- Open Graph / rich link previews -->
  <meta property="og:title"        content="{{ title }}" />
  <meta property="og:description"  content="{{ first_claim_summary }}" />
  <meta property="og:image"        content="{{ thumbnail_url }}" />
  <meta property="og:url"          content="https://informed-production.up.railway.app/share/{{ unique_id }}" />
  <meta property="og:type"         content="article" />
  <meta name="twitter:card"        content="summary_large_image" />
  <meta name="twitter:title"       content="{{ title }}" />
  <meta name="twitter:description" content="{{ first_claim_summary }}" />
  <meta name="twitter:image"       content="{{ thumbnail_url }}" />

  <style>
    /* ── Reset ── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    /* ── Tokens (match iOS app exactly) ── */
    :root {
      --brand-blue:   #1a56ff;
      --brand-teal:   #0ea5e9;
      --brand-green:  #22c55e;
      --brand-yellow: #eab308;
      --brand-red:    #ef4444;
      --bg:           #f8f9fb;
      --card-bg:      #ffffff;
      --text-primary: #0f172a;
      --text-secondary: #64748b;
      --radius-card:  24px;
      --radius-badge: 8px;
      --radius-bar:   999px;
      --shadow-card:  0 8px 32px rgba(0,0,0,0.10);
    }

    /* ── Base ── */
    html { font-size: 16px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif;
      background: var(--bg);
      color: var(--text-primary);
      min-height: 100vh;
      padding-bottom: 120px; /* space for sticky CTA */
    }

    /* ── Hero thumbnail ── */
    .hero {
      width: 100%;
      height: 260px;
      object-fit: cover;
      display: block;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    }
    .hero-placeholder {
      width: 100%;
      height: 260px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 64px;
    }
    /* Platform-specific hero gradients */
    .hero-placeholder.instagram { background: linear-gradient(135deg, #d4348a 0%, #7b22b8 100%); }
    .hero-placeholder.tiktok    { background: linear-gradient(135deg, #010101 0%, #1e1e1e 100%); }
    .hero-placeholder.youtube   { background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%); }
    .hero-placeholder.twitter   { background: linear-gradient(135deg, #1d9bf0 0%, #0e6dad 100%); }
    .hero-placeholder.threads   { background: linear-gradient(135deg, #141414 0%, #383838 100%); }

    /* ── Content card (white pill that slides up over the hero) ── */
    .card {
      background: var(--card-bg);
      border-radius: var(--radius-card) var(--radius-card) 0 0;
      margin-top: -36px;
      padding: 28px 20px 24px;
      box-shadow: var(--shadow-card);
      position: relative;
    }

    /* ── Branding bar inside card ── */
    .app-bar {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 16px;
    }
    .app-bar-logo {
      width: 28px;
      height: 28px;
      border-radius: 7px;
      background: linear-gradient(135deg, var(--brand-teal), var(--brand-blue));
      display: flex; align-items: center; justify-content: center;
      color: #fff;
      font-size: 14px;
      font-weight: 700;
      flex-shrink: 0;
    }
    .app-bar-name {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-secondary);
      letter-spacing: 0.02em;
    }

    /* ── Credibility badge ── */
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 11px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: var(--radius-badge);
      text-transform: uppercase;
      letter-spacing: 0.04em;
      margin-bottom: 10px;
    }
    .badge.high   { background: #dcfce7; color: #16a34a; }
    .badge.medium { background: #fef9c3; color: #ca8a04; }
    .badge.low    { background: #fee2e2; color: #dc2626; }

    /* ── Title ── */
    h1 {
      font-size: 22px;
      font-weight: 800;
      line-height: 1.25;
      color: var(--text-primary);
      margin-bottom: 6px;
      font-family: 'Georgia', 'Times New Roman', serif;
    }

    /* ── Meta row ── */
    .meta {
      font-size: 12px;
      color: var(--text-secondary);
      margin-bottom: 20px;
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }

    /* ── Divider ── */
    hr {
      border: none;
      border-top: 1px solid #f1f5f9;
      margin: 20px 0;
    }

    /* ── Section label ── */
    .section-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--text-secondary);
      margin-bottom: 12px;
    }

    /* ── Claim cards ── */
    .claims { display: flex; flex-direction: column; gap: 12px; }

    .claim-card {
      border-radius: 14px;
      padding: 14px 16px;
      border: 1px solid transparent;
    }
    .claim-card.high   { background: #f0fdf4; border-color: #bbf7d0; }
    .claim-card.medium { background: #fefce8; border-color: #fde68a; }
    .claim-card.low    { background: #fef2f2; border-color: #fecaca; }

    .claim-verdict-row {
      display: flex;
      align-items: center;
      gap: 7px;
      margin-bottom: 6px;
    }
    .verdict-dot {
      width: 9px; height: 9px;
      border-radius: 50%;
      flex-shrink: 0;
    }
    .verdict-dot.high   { background: var(--brand-green); }
    .verdict-dot.medium { background: var(--brand-yellow); }
    .verdict-dot.low    { background: var(--brand-red); }

    .verdict-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .verdict-label.high   { color: #16a34a; }
    .verdict-label.medium { color: #ca8a04; }
    .verdict-label.low    { color: #dc2626; }

    .claim-text {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-primary);
      line-height: 1.4;
      margin-bottom: 8px;
    }
    .claim-summary {
      font-size: 13px;
      color: var(--text-secondary);
      line-height: 1.5;
      margin-bottom: 10px;
    }

    /* ── Accuracy bar ── */
    .accuracy-row {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .bar-track {
      flex: 1;
      height: 5px;
      border-radius: var(--radius-bar);
      background: rgba(0,0,0,0.08);
      overflow: hidden;
    }
    .bar-fill {
      height: 100%;
      border-radius: var(--radius-bar);
      transition: width 0.6s ease;
    }
    .bar-fill.high   { background: var(--brand-green); }
    .bar-fill.medium { background: var(--brand-yellow); }
    .bar-fill.low    { background: var(--brand-red); }
    .accuracy-pct {
      font-size: 12px;
      font-weight: 700;
      width: 36px;
      text-align: right;
      flex-shrink: 0;
    }
    .accuracy-pct.high   { color: #16a34a; }
    .accuracy-pct.medium { color: #ca8a04; }
    .accuracy-pct.low    { color: #dc2626; }

    /* ── AI badge ── */
    .ai-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 12px;
      font-weight: 600;
      color: #ea580c;
      background: #fff7ed;
      border: 1px solid #fed7aa;
      border-radius: 20px;
      padding: 4px 10px;
      margin-top: 16px;
    }

    /* ── Teaser blur section ── */
    .teaser {
      position: relative;
      margin-top: 20px;
      border-radius: 14px;
      overflow: hidden;
      background: #f8fafc;
      border: 1px dashed #cbd5e1;
    }
    .teaser-content {
      padding: 16px;
      filter: blur(6px);
      user-select: none;
      pointer-events: none;
    }
    .teaser-label {
      font-size: 13px;
      font-weight: 600;
      color: var(--text-secondary);
      margin-bottom: 6px;
    }
    .teaser-lines {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .teaser-line {
      height: 12px;
      border-radius: 6px;
      background: #cbd5e1;
    }
    .teaser-overlay {
      position: absolute;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 6px;
      background: rgba(248, 250, 252, 0.65);
      backdrop-filter: blur(1px);
    }
    .teaser-overlay-icon { font-size: 22px; }
    .teaser-overlay-text {
      font-size: 13px;
      font-weight: 700;
      color: var(--text-primary);
      text-align: center;
      padding: 0 20px;
    }
    .teaser-overlay-sub {
      font-size: 11px;
      color: var(--text-secondary);
      text-align: center;
    }

    /* ── Sticky App Store CTA ── */
    .cta-bar {
      position: fixed;
      bottom: 0; left: 0; right: 0;
      background: rgba(255,255,255,0.92);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-top: 1px solid #e2e8f0;
      padding: 14px 20px max(14px, env(safe-area-inset-bottom));
      z-index: 100;
    }
    .cta-inner {
      display: flex;
      align-items: center;
      gap: 12px;
      max-width: 480px;
      margin: 0 auto;
    }
    .cta-app-icon {
      width: 48px; height: 48px;
      border-radius: 12px;
      background: linear-gradient(135deg, var(--brand-teal), var(--brand-blue));
      display: flex; align-items: center; justify-content: center;
      font-size: 22px;
      flex-shrink: 0;
      box-shadow: 0 4px 12px rgba(26, 86, 255, 0.3);
    }
    .cta-text { flex: 1; min-width: 0; }
    .cta-title {
      font-size: 14px;
      font-weight: 700;
      color: var(--text-primary);
      line-height: 1.2;
    }
    .cta-sub {
      font-size: 12px;
      color: var(--text-secondary);
      margin-top: 1px;
    }
    .cta-btn {
      flex-shrink: 0;
      display: inline-block;
      background: linear-gradient(135deg, var(--brand-teal), var(--brand-blue));
      color: #fff;
      font-size: 13px;
      font-weight: 700;
      padding: 9px 16px;
      border-radius: 12px;
      text-decoration: none;
      white-space: nowrap;
      box-shadow: 0 4px 12px rgba(26, 86, 255, 0.35);
    }
    .cta-btn:active { opacity: 0.85; }
  </style>
</head>
<body>

  <!-- ── Hero image or platform placeholder ── -->
  {% if thumbnail_url %}
  <img class="hero" src="{{ thumbnail_url }}" alt="Thumbnail" />
  {% else %}
  <div class="hero-placeholder {{ platform_class }}">{{ platform_emoji }}</div>
  {% endif %}

  <!-- ── Main content card ── -->
  <div class="card">

    <!-- App branding -->
    <div class="app-bar">
      <div class="app-bar-logo">✓</div>
      <span class="app-bar-name">Fact-checked by Informed AI</span>
    </div>

    <!-- Overall credibility badge -->
    <div class="badge {{ overall_level }}">
      {{ level_emoji[overall_level] }} {{ LEVEL_LABELS[overall_level] }}
    </div>

    <!-- Title -->
    <h1>{{ title }}</h1>

    <!-- Meta info -->
    <div class="meta">
      <span>{{ platform_display_name }}</span>
      <span>·</span>
      <span>{{ time_ago }}</span>
      {% if uploaded_by %}
      <span>·</span>
      <span>Shared by {{ uploaded_by }}</span>
      {% endif %}
    </div>

    <hr />

    <!-- Claims -->
    <div class="section-label">{{ claims|length }} Claim{{ 's' if claims|length != 1 }} Fact-Checked</div>
    <div class="claims">
      {% for c in claims %}
      {% set lvl = credibility_level(c.claimAccuracyRating) %}
      {% set pct_int = (c.claimAccuracyRating | replace('%','') | float) | int %}
      <div class="claim-card {{ lvl }}">
        <div class="claim-verdict-row">
          <div class="verdict-dot {{ lvl }}"></div>
          <span class="verdict-label {{ lvl }}">{{ c.verdict }}</span>
        </div>
        <div class="claim-text">{{ c.claim }}</div>
        <div class="claim-summary">{{ c.summary }}</div>
        <div class="accuracy-row">
          <div class="bar-track">
            <div class="bar-fill {{ lvl }}" style="width: {{ pct_int }}%;"></div>
          </div>
          <span class="accuracy-pct {{ lvl }}">{{ pct_int }}%</span>
        </div>
      </div>
      {% endfor %}
    </div>

    <!-- AI badge (only if flagged) -->
    {% if ai_generated == 'true' %}
    <div class="ai-badge">
      ⚠️ Possibly AI-generated content
      {% if ai_probability %} · {{ (ai_probability * 100)|int }}% confidence{% endif %}
    </div>
    {% endif %}

    <!-- Teaser — explanation & sources are blurred to encourage app download -->
    <div class="teaser">
      <div class="teaser-content">
        <div class="teaser-label">Detailed Explanation</div>
        <div class="teaser-lines">
          <div class="teaser-line" style="width:95%"></div>
          <div class="teaser-line" style="width:80%"></div>
          <div class="teaser-line" style="width:88%"></div>
          <div class="teaser-line" style="width:60%"></div>
        </div>
        <div class="teaser-label" style="margin-top:14px">Sources</div>
        <div class="teaser-lines">
          <div class="teaser-line" style="width:70%"></div>
          <div class="teaser-line" style="width:55%"></div>
        </div>
      </div>
      <div class="teaser-overlay">
        <div class="teaser-overlay-icon">🔒</div>
        <div class="teaser-overlay-text">Full explanation &amp; sources in the app</div>
        <div class="teaser-overlay-sub">Free to download · No subscription required</div>
      </div>
    </div>

  </div><!-- /card -->

  <!-- ── Sticky App Store CTA ── -->
  <div class="cta-bar">
    <div class="cta-inner">
      <div class="cta-app-icon">✓</div>
      <div class="cta-text">
        <div class="cta-title">Fact-check any reel yourself</div>
        <div class="cta-sub">Free on the App Store</div>
      </div>
      <a class="cta-btn"
         href="https://apps.apple.com/app/informed/REPLACE_WITH_YOUR_APP_ID">
        Get the App
      </a>
    </div>
  </div>

</body>
</html>
```

---

## 6. Helper Variables to Compute in Python

```python
import time
from datetime import datetime, timezone

def time_ago(iso_string):
    """Convert ISO timestamp to '2h ago' style string."""
    try:
        dt = datetime.fromisoformat(iso_string.replace('Z', '+00:00'))
        diff = int(time.time() - dt.timestamp())
        if diff < 60:     return "just now"
        if diff < 3600:   return f"{diff // 60}m ago"
        if diff < 86400:  return f"{diff // 3600}h ago"
        return f"{diff // 86400}d ago"
    except Exception:
        return "recently"

PLATFORM_INFO = {
    'instagram':     {'name': 'Instagram',   'emoji': '📸', 'class': 'instagram'},
    'tiktok':        {'name': 'TikTok',      'emoji': '🎵', 'class': 'tiktok'},
    'youtube_shorts':{'name': 'YouTube',     'emoji': '▶️', 'class': 'youtube'},
    'twitter':       {'name': 'X / Twitter', 'emoji': '🐦', 'class': 'twitter'},
    'threads':       {'name': 'Threads',     'emoji': '🧵', 'class': 'threads'},
}

def get_platform(reel):
    p = (reel.get('platform') or detect_platform(reel.get('videoLink', ''))).lower()
    return PLATFORM_INFO.get(p, PLATFORM_INFO['instagram'])

def detect_platform(url):
    url = url.lower()
    if 'tiktok.com' in url: return 'tiktok'
    if 'youtube.com/shorts' in url or 'youtu.be' in url: return 'youtube_shorts'
    if 'threads.net' in url or 'threads.com' in url: return 'threads'
    if 'twitter.com' in url or 'x.com' in url: return 'twitter'
    return 'instagram'

LEVEL_LABELS  = {'high': 'Verified', 'medium': 'Debated', 'low': 'Misleading'}
LEVEL_EMOJIS  = {'high': '✅', 'medium': '⚠️', 'low': '❌'}

# Then in your route handler, build template context:
platform_info   = get_platform(reel)
overall_level   = credibility_level(claims[0]['claimAccuracyRating'])

context = {
    'unique_id':            unique_id,
    'title':                reel['title'],
    'thumbnail_url':        reel.get('thumbnailUrl') or '',
    'platform_display_name':platform_info['name'],
    'platform_emoji':       platform_info['emoji'],
    'platform_class':       platform_info['class'],
    'time_ago':             time_ago(reel.get('checked_at', '')),
    'uploaded_by':          reel.get('uploaded_by', ''),
    'overall_level':        overall_level,
    'claims':               claims,          # list of dicts, NO explanation/sources
    'ai_generated':         reel.get('aiGenerated', ''),
    'ai_probability':       reel.get('aiProbability'),
    'first_claim_summary':  claims[0].get('summary', reel.get('summary', '')),
    'LEVEL_LABELS':         LEVEL_LABELS,
    'level_emoji':          LEVEL_EMOJIS,
}
return render_template('share_page.html', **context)
```

---

## 7. What to Strip Before Rendering

Iterate `claims` and delete these keys before passing to the template:

```python
for c in claims:
    c.pop('explanation', None)
    c.pop('sources', None)
```

This ensures even a savvy user who inspects the HTML source won't see explanations or sources.

---

## 8. 404 Page

```python
def render_share_not_found():
    return """<!DOCTYPE html>
<html><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Not Found — Informed</title>
<style>
  body{font-family:-apple-system,sans-serif;display:flex;align-items:center;
       justify-content:center;min-height:100vh;background:#f8f9fb;padding:20px}
  .box{text-align:center;max-width:320px}
  h1{font-size:20px;font-weight:800;color:#0f172a;margin:12px 0 8px}
  p{font-size:14px;color:#64748b;line-height:1.5;margin-bottom:20px}
  a{display:inline-block;background:linear-gradient(135deg,#0ea5e9,#1a56ff);
    color:#fff;font-size:14px;font-weight:700;padding:11px 22px;border-radius:12px;
    text-decoration:none}
</style></head>
<body><div class="box">
  <div style="font-size:48px">🔍</div>
  <h1>Fact Check Not Found</h1>
  <p>This link may have expired or the fact check was removed.</p>
  <a href="https://apps.apple.com/app/informed/REPLACE_WITH_YOUR_APP_ID">
    Get Informed
  </a>
</div></body></html>"""
```

---

## 9. Summary Checklist

- [ ] Add `GET /share/<unique_id>` route
- [ ] Query `fact_checks` by `uniqueID`
- [ ] Strip `explanation` and `sources` from claims before render
- [ ] Return fully server-rendered HTML (no JS required for content)
- [ ] Include all OG `<meta>` tags in `<head>`
- [ ] Replace `REPLACE_WITH_YOUR_APP_ID` in both CTA links with real App Store ID
- [ ] Return HTTP 404 with the not-found HTML if `uniqueID` not in DB
- [ ] Set `Content-Type: text/html; charset=utf-8`
