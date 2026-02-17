# URGENT: Backend Endpoints Not Implemented

## Issue
The iOS app is getting "unauthorized" errors when trying to load the public feed because the required endpoints don't exist yet.

## Error Message
```
❌ Error loading feed: unauthorized
```

## Root Cause
The frontend is trying to call `/api/public-feed` and `/api/user-reels`, but these endpoints haven't been implemented on the backend yet, so the requests are failing.

---

## 🚨 QUICK FIX: Implement These 3 Endpoints

### Priority 1: Public Feed Endpoint

```python
@app.route('/api/public-feed', methods=['GET'])
def public_feed():
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    page = int(request.args.get('page', 1))
    limit = int(request.args.get('limit', 10))
    
    # 1. Validate session (copy from your existing endpoints)
    connUser = sqlite3.connect('users.db')
    connUser.row_factory = sqlite3.Row
    cUser = connUser.cursor()
    
    cUser.execute("SELECT user_id FROM sessions WHERE session_id = ?", (session_id,))
    session = cUser.fetchone()
    
    if session is None or str(session["user_id"]) != str(user_id):
        connUser.close()
        return jsonify({"error": "Invalid session"}), 401
    
    connUser.close()
    
    # 2. Get public reels from database
    conn = sqlite3.connect('factcheck.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    offset = (page - 1) * limit
    
    # Query all fact checks (join with users table to get username)
    query = '''
        SELECT 
            fc.uniqueID, fc.link as videoLink, fc.title, fc.description,
            fc.claim, fc.is_factual as verdict, fc.confidence as claimAccuracyRating,
            fc.explanation, fc.summary, fc.sources, fc.checked_at as checkedAt, fc.date_posted as datePosted,
            fc.uploaded_by,
            u.username
        FROM fact_checks fc
        LEFT JOIN users u ON fc.uploaded_by = u.userID
        ORDER BY fc.checked_at DESC
        LIMIT ? OFFSET ?
    '''
    
    c.execute(query, (limit, offset))
    rows = c.fetchall()
    
    # Get total count
    c.execute('SELECT COUNT(*) as count FROM fact_checks')
    total_count = c.fetchone()['count']
    conn.close()
    
    # 3. Format response
    reels = []
    for row in rows:
        reels.append({
            "uniqueID": row['uniqueID'],
            "title": row['title'],
            "description": row['description'],
            "thumbnailUrl": None,  # TODO: Extract from sources or add column
            "videoLink": row['videoLink'],
            "claim": row['claim'] or "",
            "verdict": row['verdict'] or "Unknown",
            "claimAccuracyRating": row['claimAccuracyRating'] or "0%",
            "explanation": row['explanation'] or "",  # Add explanation field
            "summary": row['summary'] or "",
            "sources": json.loads(row['sources']) if row['sources'] else [],
            "checkedAt": row['checkedAt'],
            "datePosted": str(row['datePosted']) if row['datePosted'] else None,  # Convert to string
            "uploadedBy": {
                "userId": row['uploaded_by'] if row['uploaded_by'] else "anonymous",  # Never null
                "username": row['username'] if row['username'] else "Anonymous"  # Never null
            },
            "engagement": {
                "viewCount": 0,  # TODO: Add columns or query interactions table
                "shareCount": 0
            }
        })
    
    total_pages = (total_count + limit - 1) // limit
    
    return jsonify({
        "reels": reels,
        "pagination": {
            "currentPage": page,
            "totalPages": total_pages,
            "totalCount": total_count,
            "hasMore": page < total_pages,
            "nextCursor": None  # Optional for cursor-based pagination
        }
    }), 200
```

### Priority 2: User Reels Endpoint

```python
@app.route('/api/user-reels', methods=['GET'])
def user_reels():
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    limit = int(request.args.get('limit', 50))
    
    # 1. Validate session
    connUser = sqlite3.connect('users.db')
    connUser.row_factory = sqlite3.Row
    cUser = connUser.cursor()
    
    cUser.execute("SELECT user_id FROM sessions WHERE session_id = ?", (session_id,))
    session = cUser.fetchone()
    
    if session is None or str(session["user_id"]) != str(user_id):
        connUser.close()
        return jsonify({"error": "Invalid session"}), 401
    
    connUser.close()
    
    # 2. Get user's fact check IDs from user_history
    connUser = sqlite3.connect('users.db')
    connUser.row_factory = sqlite3.Row
    cUser = connUser.cursor()
    
    cUser.execute('''
        SELECT fact_check_id, checked_at 
        FROM user_history 
        WHERE userID = ? 
        ORDER BY checked_at DESC
        LIMIT ?
    ''', (user_id, limit))
    
    history = cUser.fetchall()
    connUser.close()
    
    if not history:
        return jsonify({"reels": [], "totalCount": 0}), 200
    
    # 3. Get full fact check details
    history_ids = [row['fact_check_id'] for row in history]
    
    conn = sqlite3.connect('factcheck.db')
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    placeholders = ','.join('?' * len(history_ids))
    query = f'''
        SELECT uniqueID, link, title, description, claim, is_factual as verdict,
               confidence as claimAccuracyRating, summary, sources, checked_at,
               explanation, date_posted
        FROM fact_checks
        WHERE uniqueID IN ({placeholders})
        ORDER BY checked_at DESC
    '''
    
    c.execute(query, history_ids)
    rows = c.fetchall()
    conn.close()
    
    # 4. Format response
    reels = []
    for row in rows:
        reels.append({
            "uniqueID": row['uniqueID'],
            "title": row['title'],
            "link": row['link'],
            "status": "completed",  # All from history are completed
            "thumbnailUrl": None,  # TODO: Add thumbnail support
            "submittedAt": row['checked_at'],
            "claim": row['claim'],
            "verdict": row['verdict'],
            "claimAccuracyRating": row['claimAccuracyRating'],
            "summary": row['summary'],
            "explanation": row['explanation'],  # Add explanation for full detail view
            "sources": json.loads(row['sources']) if row['sources'] else [],
            "datePosted": row['date_posted'],  # Add date posted
            "engagement": {
                "viewCount": 0,
                "shareCount": 0
            },
            "errorMessage": None
        })
    
    return jsonify({
        "reels": reels,
        "totalCount": len(reels)
    }), 200
```

### Priority 3: Track Interaction Endpoint

```python
@app.route('/api/track-interaction', methods=['POST'])
def track_interaction():
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    
    # 1. Validate session
    connUser = sqlite3.connect('users.db')
    connUser.row_factory = sqlite3.Row
    cUser = connUser.cursor()
    
    cUser.execute("SELECT user_id FROM sessions WHERE session_id = ?", (session_id,))
    session = cUser.fetchone()
    
    if session is None or str(session["user_id"]) != str(user_id):
        connUser.close()
        return jsonify({"error": "Invalid session"}), 401
    
    connUser.close()
    
    # 2. Get interaction data
    data = request.get_json()
    fact_check_id = data.get('factCheckId')
    interaction_type = data.get('interactionType')  # 'view' or 'share'
    
    if not fact_check_id or not interaction_type:
        return jsonify({"error": "Missing required fields"}), 400
    
    # 3. For now, just return success (implement counters later)
    print(f"📊 Tracked {interaction_type} for {fact_check_id} by {user_id}")
    
    return jsonify({
        "success": True,
        "message": "Interaction recorded"
    }), 200
```

---

## 🔧 ALSO UPDATE: Existing `/fact-check` Endpoint

Add `uploaded_by` tracking and return `uniqueID`:

```python
# In your /fact-check endpoint, change this:

# BEFORE:
c.execute(
    '''
    INSERT INTO fact_checks (uniqueID, link, date_posted, title, description, claim, is_factual, confidence, explanation, summary, sources)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    (uniqueID, response["link"], response["date"], response["title"],
    response["description"], response.get("claim", ""),
    response.get("verdict", ""),
    response.get("claim_accuracy_rating", ""),
    response.get("explanation", ""), response.get("summary", ""),
    sources
))

# AFTER (add uploaded_by):
c.execute(
    '''
    INSERT INTO fact_checks (uniqueID, link, date_posted, title, description, claim, is_factual, confidence, explanation, summary, sources, uploaded_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    (uniqueID, response["link"], response["date"], response["title"],
    response["description"], response.get("claim", ""),
    response.get("verdict", ""),
    response.get("claim_accuracy_rating", ""),
    response.get("explanation", ""), response.get("summary", ""),
    sources, user_id  # ADD THIS
))

# And add uniqueID to the response:
returnable = {
    "uniqueID": uniqueID,  # ADD THIS LINE
    "videoLink": response.get("link", ""),
    "thumbnail_url": response.get("thumbnail_url", None),
    # ... rest of your fields
}
```

---

## 📋 Database Changes (Optional but Recommended)

Add these columns for better features:

```sql
-- Add columns to fact_checks table
ALTER TABLE fact_checks ADD COLUMN uploaded_by TEXT;
ALTER TABLE fact_checks ADD COLUMN is_public INTEGER DEFAULT 1;
ALTER TABLE fact_checks ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE fact_checks ADD COLUMN share_count INTEGER DEFAULT 0;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_checks_public ON fact_checks(is_public, checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_fact_checks_user ON fact_checks(uploaded_by, checked_at DESC);
```

**Note:** These columns are optional for the basic functionality to work. The endpoints above will work without them, but you'll need to add them later for engagement tracking.

---

## 🧪 Test Your Endpoints

### Test 1: Public Feed
```bash
curl "http://localhost:5001/api/public-feed?userId=YOUR_USER_ID&sessionId=YOUR_SESSION_ID&page=1&limit=10"
```

Expected response:
```json
{
  "reels": [...],
  "pagination": {
    "currentPage": 1,
    "totalPages": 2,
    "totalCount": 15,
    "hasMore": true
  }
}
```

### Test 2: User Reels
```bash
curl "http://localhost:5001/api/user-reels?userId=YOUR_USER_ID&sessionId=YOUR_SESSION_ID&limit=50"
```

Expected response:
```json
{
  "reels": [...],
  "totalCount": 5
}
```

---

## ⏱️ Time Estimate

- **Endpoint 1 (public-feed):** 15-20 minutes
- **Endpoint 2 (user-reels):** 10-15 minutes  
- **Endpoint 3 (track-interaction):** 5 minutes
- **Update fact-check:** 5 minutes

**Total:** ~30-45 minutes

---

## 📞 After Implementation

Once you've added these endpoints, the iOS app will:
- ✅ Load public feed in "Discover" tab
- ✅ Show user's personal reels in "My Reels" tab
- ✅ Track views and shares
- ✅ No more "unauthorized" errors

---

## 🆘 Need Help?

If you get stuck, check:
1. `BACKEND_REQUIREMENTS.md` (comprehensive guide)
2. Your existing `/fact-check` and `/history` endpoints as reference
3. Make sure session validation matches your other endpoints

**The iOS app is ready and waiting for these endpoints!**
