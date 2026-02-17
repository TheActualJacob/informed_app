# Explanation Field: Old vs New Reels

## Current Situation

### ✅ Frontend is Ready
The iOS app now:
- ✅ Requests `explanation` field from backend
- ✅ Handles missing explanation gracefully (no crash)
- ✅ Hides Explanation section if field is empty
- ✅ Shows Explanation section if field has content

### ❌ Backend Database Issue
Your old reels in the database don't have the `explanation` field populated because:
1. They were created before we started storing explanation
2. The database column might be NULL or empty string
3. The fact-check response at the time might not have included it

## What's Happening

### For Old Reels (Before Fix)
```
Database: explanation = NULL or ""
         ↓
Backend: Returns explanation: null or ""
         ↓
iOS App: Receives empty explanation
         ↓
Detail View: Hides Explanation section (if !reel.explanation.isEmpty)
         ↓
Result: No Explanation section shown ✅ (graceful)
```

### For New Reels (After Backend Fix)
```
Fact Check: Includes explanation in response
         ↓
Backend: Stores explanation in database
         ↓
Backend: Returns explanation: "detailed text..."
         ↓
iOS App: Receives explanation
         ↓
Detail View: Shows Explanation section ✅
         ↓
Result: Full detail view with explanation
```

## Backend Fix Needed

Your backend needs to ensure the `explanation` field is being stored when fact checks are created.

### Check Current Backend Code

Look at your `/fact-check` endpoint in `backend.py`:

```python
@app.route('/fact-check', methods=['POST'])
def fact_check():
    # ... authentication code ...
    
    # After getting response from getAFactCheck:
    c.execute(
        '''
        INSERT INTO fact_checks (uniqueID, link, date_posted, title, description, claim, is_factual, confidence, explanation, summary, sources, uploaded_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        (uniqueID, response["link"], response["date"], response["title"],
        response["description"], response.get("claim", ""),
        response.get("verdict", ""),
        response.get("claim_accuracy_rating", ""),
        response.get("explanation", ""),  # ← Make sure this is here!
        response.get("summary", ""),
        sources, user_id
    ))
```

### Verify Analysis.py Returns Explanation

Check your `analysis.py` file where `getAFactCheck()` is defined:

```python
def getAFactCheck(url, shortcode):
    # ... fact checking logic ...
    
    fact_check = {
        "claim": ...,
        "verdict": ...,
        "claim_accuracy_rating": ...,
        "explanation": ...,  # ← Make sure this is extracted from AI response
        "summary": ...,
        "sources": ...
    }
    
    # Save to metadata.json
    data['fact_check'] = fact_check
```

If the AI (Gemini) is not returning explanation, you need to update your prompt to request it.

## Solution Options

### Option 1: Only New Reels Have Explanation (Recommended)
**What:** Let old reels stay without explanation, new reels will have it

**Frontend:** ✅ Already handles this! Shows explanation only if present

**Backend:** Just ensure new fact checks store explanation going forward

**Result:**
- Old reels: No Explanation section (clean)
- New reels: Full Explanation section (complete)

### Option 2: Backfill Old Reels (Optional)
**What:** Re-run fact checks on old reels to populate explanation

**Backend Script:**
```python
# One-time migration script
import sqlite3
from analysis import getAFactCheck

conn = sqlite3.connect('factcheck.db')
c = conn.cursor()

# Get all reels without explanation
c.execute("SELECT uniqueID, link FROM fact_checks WHERE explanation IS NULL OR explanation = ''")
old_reels = c.fetchall()

for reel in old_reels:
    unique_id, link = reel
    shortcode = link.split('/')[-2]
    
    # Re-run fact check
    getAFactCheck(link, shortcode)
    
    # Load result and update database
    with open(f"{shortcode}/metadata.json", 'r') as f:
        data = json.load(f)
        explanation = data['fact_check'].get('explanation', '')
        
        c.execute("UPDATE fact_checks SET explanation = ? WHERE uniqueID = ?", 
                  (explanation, unique_id))

conn.commit()
conn.close()
```

**Warning:** This will use API quota and take time!

### Option 3: Use Summary as Fallback (Quick Fix)
**What:** If explanation is empty, show summary in that section

**Backend:** In `/api/public-feed` endpoint:
```python
for row in rows:
    reels.append({
        # ... other fields ...
        "explanation": row['explanation'] if row['explanation'] else row['summary'],  # Fallback
        "summary": row['summary'] or "",
    })
```

**Result:** All reels will have something to show in explanation field

## Current Status

### ✅ What Works Now
- Frontend properly requests explanation
- Frontend handles missing explanation gracefully
- No crashes or errors
- Clean UI when explanation is missing

### ⏳ What Needs Backend Action
- Verify explanation is being stored for NEW fact checks
- Decide if you want to backfill old reels (optional)
- Update AI prompt if explanation isn't being generated

## Testing

### Test New Fact Check
1. Submit a new Instagram reel for fact checking
2. Check the backend database: `SELECT explanation FROM fact_checks WHERE uniqueID = 'latest_id'`
3. Should see explanation text, not NULL
4. View in iOS Discover tab → Should see Explanation section

### Test Old Fact Check
1. View an old reel in Discover tab
2. Should see: Claim, Verdict, Summary, Sources
3. Should NOT see: Explanation section (it's hidden)
4. No errors, clean UI

## Recommended Action Plan

### Step 1: Check if Explanation is Being Generated
Run a new fact check and check the database:
```sql
SELECT title, explanation FROM fact_checks ORDER BY checked_at DESC LIMIT 1;
```

If explanation is empty → Fix AI prompt/extraction in `analysis.py`

### Step 2: Verify Storage
Check your `/fact-check` endpoint includes explanation in INSERT statement

### Step 3: Test
Submit a new reel and verify explanation appears in iOS app

### Step 4: Decide on Old Reels
- Leave them without explanation (recommended)
- OR backfill them (takes time and API quota)

## Summary

**Current State:**
- ✅ Frontend handles both cases (with/without explanation)
- ✅ Old reels show clean UI without explanation
- ✅ New reels WILL show explanation (once backend is fixed)
- ⏳ Backend needs to ensure explanation is stored

**What You See:**
- Old reels: No Explanation section (expected, graceful)
- New reels: Should have Explanation section (after backend fix)

**What Backend Needs:**
1. Verify `explanation` is in fact check response
2. Verify `explanation` is stored in database
3. Verify `explanation` is returned in API responses

**No Frontend Changes Needed!** The app is ready to handle both scenarios.

---

**Status:** ✅ Frontend Complete  
**Issue:** Backend not storing/returning explanation for old reels  
**Solution:** Backend team needs to verify explanation is being captured and stored  
**Impact:** Old reels gracefully hide explanation, new reels will show it once backend is fixed
