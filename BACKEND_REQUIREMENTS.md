# Backend Requirements for Enhanced User History & Public Feed

## Overview
This document outlines the backend changes needed to implement:
1. **Enhanced User History Management** for shared reels
2. **Public Feed API** to display reels from all users
3. **User engagement tracking** (views, shares, etc.)

---

## 1. Database Schema Changes

### 1.1 Extend `fact_checks` Table
Add user association and engagement metrics to track who uploaded what:

```sql
ALTER TABLE fact_checks ADD COLUMN uploaded_by TEXT;
ALTER TABLE fact_checks ADD COLUMN is_public INTEGER DEFAULT 1;
ALTER TABLE fact_checks ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE fact_checks ADD COLUMN share_count INTEGER DEFAULT 0;

-- Index for efficient public feed queries
CREATE INDEX IF NOT EXISTS idx_fact_checks_public ON fact_checks(is_public, checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_fact_checks_user ON fact_checks(uploaded_by, checked_at DESC);
```

### 1.2 Create `reel_interactions` Table (Optional - for future features)
Track user interactions with reels (likes, bookmarks, etc.):

```sql
CREATE TABLE IF NOT EXISTS reel_interactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    fact_check_id TEXT NOT NULL,
    interaction_type TEXT NOT NULL, -- 'view', 'like', 'bookmark', 'share'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(userID),
    FOREIGN KEY (fact_check_id) REFERENCES fact_checks(uniqueID),
    UNIQUE(user_id, fact_check_id, interaction_type)
);

CREATE INDEX IF NOT EXISTS idx_interactions_user ON reel_interactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_reel ON reel_interactions(fact_check_id, interaction_type);
```

---

## 2. New API Endpoints

### 2.1 **GET /api/public-feed**
Retrieve paginated public reels from all users.

**Query Parameters:**
- `userId` (required): Current user's ID for session validation
- `sessionId` (required): Session ID for authentication
- `page` (optional, default=1): Page number for pagination
- `limit` (optional, default=10): Number of items per page
- `cursor` (optional): Timestamp cursor for infinite scroll (alternative to page)

**Response Structure:**
```json
{
  "reels": [
    {
      "uniqueID": "uuid-string",
      "title": "Fact check title",
      "description": "Description",
      "thumbnailUrl": "https://...",
      "videoLink": "https://...",
      "claim": "The claim being checked",
      "verdict": "True/False/Misleading",
      "claimAccuracyRating": "85%",
      "summary": "Brief summary",
      "sources": ["https://...", "https://..."],
      "checkedAt": "2026-02-17T10:30:00Z",
      "datePosted": "2026-02-15",
      "uploadedBy": {
        "userId": "user-uuid",
        "username": "john_doe"
      },
      "engagement": {
        "viewCount": 150,
        "shareCount": 12
      }
    }
  ],
  "pagination": {
    "currentPage": 1,
    "totalPages": 5,
    "totalCount": 47,
    "hasMore": true,
    "nextCursor": "2026-02-17T10:30:00Z" // For cursor-based pagination
  }
}
```

**Implementation Notes:**
- Order by `checked_at DESC` (newest first)
- Only return reels where `is_public = 1`
- Include username by joining with `users` table
- Implement cursor-based pagination for better infinite scroll performance
- Exclude reels from blocked/reported users (if you add that feature)

**Example SQL Query:**
```sql
SELECT 
    fc.uniqueID, fc.link, fc.title, fc.description, fc.claim,
    fc.is_factual as verdict, fc.confidence as claimAccuracyRating,
    fc.explanation, fc.summary, fc.sources, fc.checked_at,
    fc.date_posted, fc.view_count, fc.share_count,
    fc.uploaded_by,
    u.username
FROM fact_checks fc
LEFT JOIN users u ON fc.uploaded_by = u.userID
WHERE fc.is_public = 1
ORDER BY fc.checked_at DESC
LIMIT ? OFFSET ?
```

---

### 2.2 **GET /api/user-reels**
Get all reels submitted by the current user (enhanced version of existing functionality).

**Query Parameters:**
- `userId` (required): User's ID
- `sessionId` (required): Session ID for authentication
- `limit` (optional, default=50): Number of items to return

**Response Structure:**
```json
{
  "reels": [
    {
      "uniqueID": "uuid-string",
      "title": "Fact check title",
      "link": "https://instagram.com/reel/...",
      "status": "completed", // "pending" | "processing" | "completed" | "failed"
      "thumbnailUrl": "https://...",
      "submittedAt": "2026-02-17T10:30:00Z",
      "claim": "The claim",
      "verdict": "True",
      "claimAccuracyRating": "95%",
      "summary": "Summary text",
      "sources": ["https://..."],
      "engagement": {
        "viewCount": 50,
        "shareCount": 3
      },
      "errorMessage": null // Only present if status is "failed"
    }
  ],
  "totalCount": 25
}
```

**Implementation Notes:**
- Query `user_history` table to get user's fact check IDs
- Join with `fact_checks` table to get full details
- Include engagement metrics
- Order by submission date (newest first)

---

### 2.3 **POST /api/track-interaction**
Track user interactions with reels (views, shares, etc.).

**Request Body:**
```json
{
  "factCheckId": "uuid-string",
  "interactionType": "view" // "view" | "share" | "like" | "bookmark"
}
```

**Query Parameters:**
- `userId` (required): User's ID
- `sessionId` (required): Session ID

**Response:**
```json
{
  "success": true,
  "message": "Interaction recorded"
}
```

**Implementation Notes:**
- Insert or update interaction in `reel_interactions` table
- Update counters in `fact_checks` table (e.g., `view_count++`)
- Use `INSERT OR IGNORE` to prevent duplicate view counts
- For shares, increment `share_count` in `fact_checks` table

---

### 2.4 **Enhanced POST /fact-check**
Update the existing fact-check endpoint to track who uploaded the reel.

**Changes Needed:**
1. Store `uploaded_by` user ID when inserting into `fact_checks`
2. Set `is_public = 1` by default (or add parameter to control privacy)
3. Return the `uniqueID` in response so frontend can track it

**Updated Response:**
```json
{
  "uniqueID": "uuid-string", // ADD THIS
  "videoLink": "https://...",
  "thumbnail_url": "https://...",
  "date": "2026-02-15",
  "title": "Title",
  "claim": "Claim text",
  "verdict": "True",
  "claim_accuracy_rating": "95%",
  "explanation": "Explanation",
  "summary": "Summary",
  "sources": ["https://..."],
  "checkedAt": "2026-02-17T10:30:00Z"
}
```

**Updated SQL Insert:**
```python
c.execute(
    '''
    INSERT INTO fact_checks (uniqueID, link, date_posted, title, description, 
                            claim, is_factual, confidence, explanation, summary, 
                            sources, uploaded_by, is_public)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    (uniqueID, response["link"], response["date"], response["title"],
     response["description"], response.get("claim", ""),
     response.get("verdict", ""), response.get("claim_accuracy_rating", ""),
     response.get("explanation", ""), response.get("summary", ""),
     sources, user_id, 1)  # ADD user_id and is_public
)
```

---

### 2.5 **GET /api/sync-history**
Sync user's complete history (useful when app reinstalls or switches devices).

**Query Parameters:**
- `userId` (required)
- `sessionId` (required)
- `since` (optional): ISO timestamp to get only new items since last sync

**Response:** Same as `/api/user-reels`

---

## 3. Existing Endpoint Enhancements

### 3.1 **GET /history**
Current implementation is good, but consider these enhancements:

**Improvements:**
1. ✅ Already returns up to 50 items (good)
2. ✅ Already validates session (good)
3. 🔄 **Consider adding pagination** if users have >50 history items
4. 🔄 **Add thumbnail URLs** to response (join fact_checks table)
5. 🔄 **Add engagement metrics** to show user how popular their checks were

**Enhanced Response:**
```json
[
  {
    "uniqueID": "uuid",
    "link": "https://...",
    "title": "Title",
    "thumbnailUrl": "https://...", // ADD THIS
    "claim": "Claim",
    "verdict": "True",
    "confidence": "95%",
    "summary": "Summary",
    "sources": ["https://..."],
    "checkedAt": "2026-02-17T10:30:00Z",
    "engagement": {  // ADD THIS
      "viewCount": 50,
      "shareCount": 3
    }
  }
]
```

---

## 4. Implementation Checklist

### Phase 1: Database Changes
- [ ] Run migration to add columns to `fact_checks` table
- [ ] Create indexes for efficient queries
- [ ] (Optional) Create `reel_interactions` table
- [ ] Test backward compatibility with existing data

### Phase 2: Endpoint Implementation
- [ ] Implement `/api/public-feed` with pagination
- [ ] Implement `/api/user-reels` endpoint
- [ ] Implement `/api/track-interaction` endpoint
- [ ] Update `/fact-check` to store `uploaded_by` and return `uniqueID`
- [ ] Enhance `/history` endpoint with thumbnails and engagement

### Phase 3: Testing
- [ ] Test pagination with various page sizes
- [ ] Test with multiple users
- [ ] Test session validation
- [ ] Test performance with large datasets
- [ ] Test error handling (invalid users, expired sessions, etc.)

---

## 5. Performance Considerations

### 5.1 Caching
Consider caching the public feed for 1-5 minutes to reduce database load:
```python
from flask_caching import Cache

cache = Cache(app, config={'CACHE_TYPE': 'simple'})

@app.route('/api/public-feed')
@cache.cached(timeout=300, query_string=True)  # Cache for 5 minutes
def public_feed():
    # ... implementation
```

### 5.2 Database Optimization
- Use prepared statements (you're already doing this ✅)
- Add indexes on frequently queried columns (see Section 1)
- Consider denormalizing engagement counts for faster reads
- Use `EXPLAIN QUERY PLAN` to optimize slow queries

### 5.3 Pagination Strategy
**Cursor-based vs Offset-based:**
- **Offset-based**: Simple but slower with large offsets
  - Good for: Small datasets, page number display needed
  - Example: `LIMIT 10 OFFSET 40`

- **Cursor-based**: Faster, better for infinite scroll
  - Good for: Infinite scroll, real-time feeds
  - Example: `WHERE checked_at < ? ORDER BY checked_at DESC LIMIT 10`

**Recommendation**: Implement cursor-based for public feed (infinite scroll).

---

## 6. Security & Privacy Considerations

### 6.1 Privacy Controls (Future Enhancement)
Allow users to make reels private:
```python
@app.route('/api/reel/<reel_id>/privacy', methods=['PUT'])
def update_privacy():
    # Update is_public field
    # Validate user owns the reel
```

### 6.2 Rate Limiting
Implement rate limiting to prevent abuse:
```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=lambda: request.args.get('userId'))

@app.route('/api/public-feed')
@limiter.limit("100 per minute")
def public_feed():
    # ... implementation
```

### 6.3 Content Moderation
Consider adding:
- Report/flag functionality
- Admin review queue
- Automated content filtering

---

## 7. Example Implementation (Python/Flask)

### 7.1 Public Feed Endpoint
```python
@app.route('/api/public-feed', methods=['GET'])
def public_feed():
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    page = int(request.args.get('page', 1))
    limit = min(int(request.args.get('limit', 10)), 50)  # Max 50 per request
    cursor = request.args.get('cursor')  # Optional timestamp cursor
    
    # Validate session
    if not validate_session(user_id, session_id):
        return jsonify({"error": "Invalid session"}), 401
    
    conn = sqlite3.connect('factcheck.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    # Cursor-based pagination for infinite scroll
    if cursor:
        query = '''
            SELECT 
                fc.uniqueID, fc.link, fc.title, fc.description, fc.claim,
                fc.is_factual as verdict, fc.confidence as claimAccuracyRating,
                fc.summary, fc.sources, fc.checked_at, fc.date_posted,
                fc.view_count, fc.share_count, fc.uploaded_by,
                u.username
            FROM fact_checks fc
            LEFT JOIN users u ON fc.uploaded_by = u.userID
            WHERE fc.is_public = 1 AND fc.checked_at < ?
            ORDER BY fc.checked_at DESC
            LIMIT ?
        '''
        c.execute(query, (cursor, limit))
    else:
        # Offset-based for page numbers
        offset = (page - 1) * limit
        query = '''
            SELECT 
                fc.uniqueID, fc.link, fc.title, fc.description, fc.claim,
                fc.is_factual as verdict, fc.confidence as claimAccuracyRating,
                fc.summary, fc.sources, fc.checked_at, fc.date_posted,
                fc.view_count, fc.share_count, fc.uploaded_by,
                u.username
            FROM fact_checks fc
            LEFT JOIN users u ON fc.uploaded_by = u.userID
            WHERE fc.is_public = 1
            ORDER BY fc.checked_at DESC
            LIMIT ? OFFSET ?
        '''
        c.execute(query, (limit, offset))
    
    rows = c.fetchall()
    
    # Get total count for pagination
    c.execute('SELECT COUNT(*) as count FROM fact_checks WHERE is_public = 1')
    total_count = c.fetchone()['count']
    conn.close()
    
    # Format response
    reels = []
    for row in rows:
        reels.append({
            "uniqueID": row['uniqueID'],
            "title": row['title'],
            "description": row['description'],
            "thumbnailUrl": get_thumbnail_from_sources(row['link']),  # Helper function
            "videoLink": row['link'],
            "claim": row['claim'],
            "verdict": row['verdict'],
            "claimAccuracyRating": row['claimAccuracyRating'],
            "summary": row['summary'],
            "sources": json.loads(row['sources']) if row['sources'] else [],
            "checkedAt": row['checked_at'],
            "datePosted": row['date_posted'],
            "uploadedBy": {
                "userId": row['uploaded_by'],
                "username": row['username'] or "Anonymous"
            },
            "engagement": {
                "viewCount": row['view_count'] or 0,
                "shareCount": row['share_count'] or 0
            }
        })
    
    total_pages = (total_count + limit - 1) // limit
    has_more = page < total_pages if not cursor else len(reels) == limit
    next_cursor = reels[-1]['checkedAt'] if reels and cursor else None
    
    return jsonify({
        "reels": reels,
        "pagination": {
            "currentPage": page,
            "totalPages": total_pages,
            "totalCount": total_count,
            "hasMore": has_more,
            "nextCursor": next_cursor
        }
    }), 200


def validate_session(user_id, session_id):
    """Helper function to validate user session"""
    conn = sqlite3.connect('users.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT user_id FROM sessions WHERE session_id = ?", (session_id,))
    session = c.fetchone()
    conn.close()
    return session and str(session['user_id']) == str(user_id)
```

### 7.2 Track Interaction Endpoint
```python
@app.route('/api/track-interaction', methods=['POST'])
def track_interaction():
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    
    if not validate_session(user_id, session_id):
        return jsonify({"error": "Invalid session"}), 401
    
    data = request.get_json()
    fact_check_id = data.get('factCheckId')
    interaction_type = data.get('interactionType')  # 'view', 'share', etc.
    
    if not fact_check_id or not interaction_type:
        return jsonify({"error": "Missing required fields"}), 400
    
    conn = sqlite3.connect('factcheck.db')
    c = conn.cursor()
    
    # Update engagement counters
    if interaction_type == 'view':
        c.execute(
            'UPDATE fact_checks SET view_count = view_count + 1 WHERE uniqueID = ?',
            (fact_check_id,)
        )
    elif interaction_type == 'share':
        c.execute(
            'UPDATE fact_checks SET share_count = share_count + 1 WHERE uniqueID = ?',
            (fact_check_id,)
        )
    
    conn.commit()
    conn.close()
    
    return jsonify({"success": True, "message": "Interaction recorded"}), 200
```

---

## 8. Frontend Integration Guide

The frontend will need to:

1. **Public Feed Tab**:
   - Call `/api/public-feed` on load
   - Implement infinite scroll (load more on scroll to bottom)
   - Display reel cards with thumbnail, title, verdict badge
   - Show username of who uploaded each reel

2. **Shared Reels Tab**:
   - Call `/api/user-reels` to get user's submissions
   - Add pull-to-refresh to sync from backend
   - Show submission status (pending/processing/completed/failed)
   - Display engagement metrics (views, shares)

3. **Tracking**:
   - Call `/api/track-interaction` when user views a reel detail
   - Track shares back to the backend
   - Consider tracking time spent on each reel

4. **Caching & Sync**:
   - Cache public feed locally for offline viewing
   - Sync user history on app launch
   - Show loading states during fetches

---

## 9. Success Metrics

Track these metrics to measure feature success:

- **User Engagement**: Average time spent in public feed
- **Content Creation**: Number of reels uploaded per user
- **Virality**: Share count distribution
- **Retention**: Users returning to check public feed
- **API Performance**: Response times for feed endpoint (<200ms target)

---

## 10. Future Enhancements

Consider implementing later:
- 🔮 **Following/Followers**: Let users follow others
- 🔮 **Comments**: Allow discussions on fact-checks
- 🔮 **Reactions**: Like/dislike buttons
- 🔮 **Bookmarks**: Save reels for later
- 🔮 **Search**: Search public reels by keywords
- 🔮 **Trending**: Show most-viewed reels this week
- 🔮 **Notifications**: Alert when your reel gets views/shares
- 🔮 **User Profiles**: Public profile pages showing user's contributions

---

## Questions or Clarifications?

Contact the frontend team if you need:
- Different response formats
- Additional fields in responses
- Changed pagination strategies
- Different endpoint URLs

**Last Updated**: February 17, 2026
