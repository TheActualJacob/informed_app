# URGENT: Backend Missing Explanation Field

## Problem
The Discover tab detail views show "No detailed explanation available" for all reels because the backend is not returning the `explanation` field in the `/api/public-feed` endpoint response.

## What's Happening

### Frontend (iOS App)
✅ Correctly requests explanation field
✅ Properly decodes it (with fallback to empty string)
✅ Shows explanation section with message if empty

### Backend Issue
❌ Not returning `explanation` in the response
❌ SQL query might not be selecting it
❌ Or database column is NULL/empty

## Quick Check

Run this on your backend:

```bash
# Check if explanation column exists and has data
sqlite3 factcheck.db "SELECT uniqueID, title, explanation FROM fact_checks LIMIT 5;"
```

**Expected:** Should see explanation text
**If you see NULL or empty:** The data isn't being stored

## Fix 1: Update SQL Query in `/api/public-feed`

Your backend endpoint needs to SELECT the explanation field:

```python
@app.route('/api/public-feed', methods=['GET'])
def public_feed():
    # ... authentication code ...
    
    # Make sure explanation is in the SELECT statement!
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
    
    # Make sure explanation is in the response!
    reels = []
    for row in rows:
        reels.append({
            "uniqueID": row['uniqueID'],
            "title": row['title'],
            "description": row['description'],
            "thumbnailUrl": None,
            "videoLink": row['videoLink'],
            "claim": row['claim'] or "",
            "verdict": row['verdict'] or "Unknown",
            "claimAccuracyRating": row['claimAccuracyRating'] or "0%",
            "explanation": row['explanation'] or "",  # ← THIS LINE!
            "summary": row['summary'] or "",
            "sources": json.loads(row['sources']) if row['sources'] else [],
            "checkedAt": row['checkedAt'],
            "datePosted": str(row['datePosted']) if row['datePosted'] else None,
            "uploadedBy": {
                "userId": row['uploaded_by'] if row['uploaded_by'] else "anonymous",
                "username": row['username'] if row['username'] else "Anonymous"
            },
            "engagement": {
                "viewCount": 0,
                "shareCount": 0
            }
        })
    
    return jsonify({
        "reels": reels,
        "pagination": {...}
    }), 200
```

## Fix 2: Ensure Explanation is Being Stored

Check your `/fact-check` endpoint stores explanation:

```python
@app.route('/fact-check', methods=['POST'])
def fact_check():
    # ... fact check logic ...
    
    # When inserting to database:
    c.execute(
        '''
        INSERT INTO fact_checks (uniqueID, link, date_posted, title, description, 
                                claim, is_factual, confidence, explanation, summary, sources, uploaded_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        (uniqueID, response["link"], response["date"], response["title"],
        response["description"], response.get("claim", ""),
        response.get("verdict", ""),
        response.get("claim_accuracy_rating", ""),
        response.get("explanation", ""),  # ← Make sure this gets the explanation from AI!
        response.get("summary", ""),
        sources, user_id
    ))
```

## Fix 3: Check AI Response Includes Explanation

In your `analysis.py` or wherever you call the AI:

```python
def getAFactCheck(url, shortcode):
    # ... extract content ...
    
    # Make sure your prompt asks for explanation
    prompt = f"""
    Analyze this content and provide:
    1. Claim: What is being claimed
    2. Verdict: True/False/Misleading
    3. Accuracy Rating: 0-100%
    4. Summary: Brief overview
    5. Explanation: DETAILED analysis of why the verdict was reached  ← THIS!
    6. Sources: List of sources
    """
    
    # Parse AI response
    fact_check = {
        "claim": ...,
        "verdict": ...,
        "claim_accuracy_rating": ...,
        "summary": ...,
        "explanation": ...,  # ← Make sure this is extracted!
        "sources": [...]
    }
    
    return fact_check
```

## Test It

### Step 1: Check Database
```bash
sqlite3 factcheck.db "SELECT explanation FROM fact_checks WHERE explanation IS NOT NULL AND explanation != '' LIMIT 1;"
```

If this returns nothing → Explanation isn't being stored

### Step 2: Test API Response
```bash
curl "http://localhost:5001/api/public-feed?userId=test&sessionId=test&page=1&limit=1" | jq '.reels[0].explanation'
```

Should see explanation text, not empty string or null

### Step 3: Test in iOS App
1. Open Discover tab
2. Tap any reel
3. Scroll to Explanation section
4. Should see detailed text (not "No detailed explanation available")

## What iOS App Expects

```json
{
  "reels": [
    {
      "uniqueID": "...",
      "title": "...",
      "claim": "...",
      "verdict": "...",
      "summary": "This is a brief summary",
      "explanation": "This is a detailed explanation of why we reached this verdict. It includes analysis of the claim, evidence found, credibility of sources, and reasoning behind the accuracy rating.",
      "sources": [...]
    }
  ]
}
```

## Current vs Expected

### What Backend is Returning (Wrong)
```json
{
  "explanation": ""  // Empty!
}
```

### What Backend Should Return (Correct)
```json
{
  "explanation": "Detailed analysis text here..."
}
```

## Priority

🔴 **HIGH PRIORITY** - This affects user experience significantly

Users can't understand WHY a fact check reached its verdict without the explanation.

## Files to Check

1. **backend.py** - `/api/public-feed` endpoint
   - SQL SELECT must include `fc.explanation`
   - Response JSON must include `"explanation": row['explanation']`

2. **backend.py** - `/fact-check` endpoint
   - INSERT must include explanation column
   - Must store `response.get("explanation", "")`

3. **analysis.py** - `getAFactCheck()` function
   - AI prompt must request explanation
   - Response parsing must extract explanation

## Quick Verification Checklist

- [ ] Database has explanation column
- [ ] Explanation column has data (not NULL)
- [ ] SQL query SELECTs explanation
- [ ] API response includes explanation
- [ ] iOS app receives explanation
- [ ] Detail view shows explanation

## Summary

**Problem:** Backend not returning explanation field
**Impact:** Users see "No detailed explanation available"
**Solution:** Add explanation to SQL query and response
**Files:** backend.py (2 endpoints), possibly analysis.py
**Priority:** High - affects all Discover detail views

---

See `BACKEND_URGENT_FIX.md` lines 45-90 for complete implementation.
