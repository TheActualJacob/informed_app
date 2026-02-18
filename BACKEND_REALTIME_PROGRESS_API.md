# Backend Real-Time Progress Tracking API - Implementation Guide

## Overview

This guide provides complete specifications for implementing real-time progress tracking for Instagram reel fact-checking to power the Dynamic Island UI in the iOS app.

**Date:** February 19, 2026  
**Version:** 1.0  
**Priority:** High

---

## Current System Architecture

### iOS App Flow
1. **User shares reel** from Instagram → Share Extension activated
2. **Share Extension** sends POST to `/fact-check` with submission_id
3. **Backend** processes asynchronously (typically 60-120 seconds)
4. **iOS app** displays Dynamic Island with progress animation
5. **iOS app** polls `/api/submission-status/:id` every 3 seconds
6. **Dynamic Island** updates with real progress from backend
7. **Completion** → Live Activity dismisses, user views results

### Problem to Solve
Currently, the iOS app uses **hardcoded progress stages** (10%, 30%, 60%, 85%, 100%) that don't reflect actual processing status. We need the backend to provide **real-time progress updates** so users see accurate processing information.

---

## Required API Changes

### 1. New Endpoint: GET /api/submission-status/:id

Returns current processing status for a given submission.

**Endpoint:** `GET /api/submission-status/:submission_id`

**Authentication:** Query parameters `userId` and `sessionId`

**Request Example:**
```http
GET /api/submission-status/abc123-def456-789?userId=user_xyz&sessionId=session_abc
```

**Response Format (200 OK):**
```json
{
  "submission_id": "abc123-def456-789",
  "status": "analyzing",
  "progress_percentage": 65,
  "current_stage": "Analyzing video content",
  "estimated_seconds_remaining": 35,
  "created_at": "2026-02-19T10:30:00Z",
  "updated_at": "2026-02-19T10:31:05Z"
}
```

**Status Values and Typical Progress:**

| Status | Progress Range | Description | Est. Time Remaining |
|--------|---------------|-------------|---------------------|
| `submitting` | 5-10% | Initial request received | ~85-90s |
| `downloading` | 10-20% | Downloading video from Instagram | ~70-80s |
| `processing` | 20-40% | Extracting audio and video frames | ~50-70s |
| `analyzing` | 40-70% | Running content analysis | ~30-50s |
| `fact_checking` | 70-95% | Verifying claims against sources | ~10-25s |
| `completed` | 100% | Fact-check complete | 0s |
| `failed` | 0% | Processing failed | 0s |

**Error Response (404 Not Found):**
```json
{
  "error": "Submission not found",
  "submission_id": "abc123-def456-789"
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": "Invalid credentials",
  "message": "userId or sessionId not valid"
}
```

---

### 2. Updated Endpoint: POST /fact-check

**Changes Required:**

#### Add to Response
The endpoint should now return `submission_id` and initial status info:

```json
{
  "submission_id": "abc123-def456-789",
  "initial_status": "submitting",
  "progress_percentage": 10,
  "estimated_total_seconds": 90,
  
  // Existing fields (if completing synchronously):
  "status": "processing",
  "title": "Video Title",
  "claim": "...",
  "verdict": "...",
  // etc...
}
```

#### Support Two Response Modes

**Mode 1: Asynchronous (Recommended)**
Backend immediately returns 202 Accepted with tracking info:
```json
HTTP/1.1 202 Accepted
{
  "submission_id": "abc123-def456-789",
  "status": "processing",
  "message": "Fact-check started, poll /api/submission-status/abc123-def456-789 for updates"
}
```

**Mode 2: Synchronous (For fast processing)**
If fact-check completes quickly (<5s), return full results immediately:
```json
HTTP/1.1 200 OK
{
  "submission_id": "abc123-def456-789",
  "status": "completed",
  "progress_percentage": 100,
  "title": "Fact Check Title",
  // ... full fact-check data
}
```

---

## Database Schema Changes

Add progress tracking columns to your submissions/fact_checks table:

### SQL Migration Script

```sql
-- Add progress tracking columns
ALTER TABLE fact_checks 
  ADD COLUMN processing_status VARCHAR(50) DEFAULT 'submitting',
  ADD COLUMN progress_percentage INTEGER DEFAULT 0,
  ADD COLUMN current_stage VARCHAR(255) DEFAULT 'Submitting',
  ADD COLUMN estimated_seconds_remaining INTEGER DEFAULT 90,
  ADD COLUMN status_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Create index for fast status lookups
CREATE INDEX IF NOT EXISTS idx_fact_checks_submission_status 
  ON fact_checks(submission_id, processing_status);

-- Add trigger to auto-update status_updated_at
CREATE TRIGGER update_status_timestamp 
  BEFORE UPDATE ON fact_checks
  FOR EACH ROW
  WHEN (OLD.processing_status != NEW.processing_status 
        OR OLD.progress_percentage != NEW.progress_percentage)
  EXECUTE FUNCTION update_status_updated_at();
```

---

## Implementation Guide

### Step 1: Update Database Model

Add fields to your FactCheck/Submission model:

**Python (SQLAlchemy) Example:**
```python
class FactCheck(db.Model):
    __tablename__ = 'fact_checks'
    
    submission_id = db.Column(db.String(255), unique=True, index=True)
    processing_status = db.Column(db.String(50), default='submitting')
    progress_percentage = db.Column(db.Integer, default=0)
    current_stage = db.Column(db.String(255), default='Submitting')
    estimated_seconds_remaining = db.Column(db.Integer, default=90)
    status_updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # ... existing fields (title, claim, verdict, etc.)
```

**Node.js (Sequelize) Example:**
```javascript
const FactCheck = sequelize.define('FactCheck', {
  submissionId: { type: DataTypes.STRING, unique: true },
  processingStatus: { type: DataTypes.STRING, defaultValue: 'submitting' },
  progressPercentage: { type: DataTypes.INTEGER, defaultValue: 0 },
  currentStage: { type: DataTypes.STRING, defaultValue: 'Submitting' },
  estimatedSecondsRemaining: { type: DataTypes.INTEGER, defaultValue: 90 },
  statusUpdatedAt: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});
```

---

### Step 2: Create Helper Function to Update Progress

**Python Example:**
```python
def update_submission_progress(submission_id, status, progress, stage, estimated_remaining):
    """Update progress for a fact-check submission"""
    fact_check = FactCheck.query.filter_by(submission_id=submission_id).first()
    
    if not fact_check:
        print(f"Warning: Submission {submission_id} not found")
        return False
    
    fact_check.processing_status = status
    fact_check.progress_percentage = progress
    fact_check.current_stage = stage
    fact_check.estimated_seconds_remaining = estimated_remaining
    
    db.session.commit()
    
    print(f"[Progress] {submission_id}: {status} - {progress}% - {stage} - {estimated_remaining}s remaining")
    return True
```

**Node.js Example:**
```javascript
async function updateSubmissionProgress(submissionId, status, progress, stage, estimatedRemaining) {
  const factCheck = await FactCheck.findOne({ where: { submissionId } });
  
  if (!factCheck) {
    console.log(`Warning: Submission ${submissionId} not found`);
    return false;
  }
  
  await factCheck.update({
    processingStatus: status,
    progressPercentage: progress,
    currentStage: stage,
    estimatedSecondsRemaining: estimatedRemaining,
    statusUpdatedAt: new Date()
  });
  
  console.log(`[Progress] ${submissionId}: ${status} - ${progress}% - ${stage} - ${estimatedRemaining}s remaining`);
  return true;
}
```

---

### Step 3: Instrument Your Processing Pipeline

Add progress updates at key points in your fact-checking pipeline:

**Example Processing Flow with Progress Updates:**

```python
def process_fact_check(submission_id, instagram_url):
    """Main fact-check processing function"""
    
    # Stage 1: Download video (10-20%)
    update_submission_progress(submission_id, 'downloading', 15, 'Downloading video', 75)
    video_file = download_instagram_video(instagram_url)
    
    # Stage 2: Extract audio/frames (20-40%)
    update_submission_progress(submission_id, 'processing', 30, 'Extracting audio and frames', 60)
    audio_file = extract_audio(video_file)
    frames = extract_key_frames(video_file)
    
    # Stage 3: Transcribe audio (40-50%)
    update_submission_progress(submission_id, 'analyzing', 45, 'Transcribing audio', 45)
    transcript = transcribe_audio(audio_file)
    
    # Stage 4: Analyze content (50-65%)
    update_submission_progress(submission_id, 'analyzing', 55, 'Analyzing content', 35)
    content_analysis = analyze_content(transcript, frames)
    
    # Stage 5: Extract claims (65-75%)
    update_submission_progress(submission_id, 'fact_checking', 70, 'Extracting claims', 25)
    claims = extract_claims(content_analysis)
    
    # Stage 6: Verify claims (75-90%)
    update_submission_progress(submission_id, 'fact_checking', 80, 'Verifying claims', 15)
    fact_check_results = verify_claims(claims)
    
    # Stage 7: Generate report (90-95%)
    update_submission_progress(submission_id, 'fact_checking', 92, 'Generating report', 8)
    report = generate_report(fact_check_results)
    
    # Stage 8: Complete (100%)
    update_submission_progress(submission_id, 'completed', 100, 'Fact-check complete', 0)
    
    return report
```

---

### Step 4: Implement GET /api/submission-status/:id

**Python (Flask) Example:**
```python
@app.route('/api/submission-status/<submission_id>', methods=['GET'])
def get_submission_status(submission_id):
    # Authenticate
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    
    if not validate_session(user_id, session_id):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Find submission
    fact_check = FactCheck.query.filter_by(submission_id=submission_id).first()
    
    if not fact_check:
        return jsonify({'error': 'Submission not found', 'submission_id': submission_id}), 404
    
    # Verify user owns this submission
    if fact_check.uploaded_by != user_id:
        return jsonify({'error': 'Unauthorized'}), 403
    
    # Return progress
    return jsonify({
        'submission_id': fact_check.submission_id,
        'status': fact_check.processing_status,
        'progress_percentage': fact_check.progress_percentage,
        'current_stage': fact_check.current_stage,
        'estimated_seconds_remaining': fact_check.estimated_seconds_remaining,
        'created_at': fact_check.created_at.isoformat(),
        'updated_at': fact_check.status_updated_at.isoformat()
    })
```

**Node.js (Express) Example:**
```javascript
app.get('/api/submission-status/:submissionId', async (req, res) => {
  const { submissionId } = req.params;
  const { userId, sessionId } = req.query;
  
  // Authenticate
  if (!await validateSession(userId, sessionId)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  
  // Find submission
  const factCheck = await FactCheck.findOne({ where: { submissionId } });
  
  if (!factCheck) {
    return res.status(404).json({ 
      error: 'Submission not found', 
      submission_id: submissionId 
    });
  }
  
  // Verify ownership
  if (factCheck.uploadedBy !== userId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }
  
  // Return progress
  res.json({
    submission_id: factCheck.submissionId,
    status: factCheck.processingStatus,
    progress_percentage: factCheck.progressPercentage,
    current_stage: factCheck.currentStage,
    estimated_seconds_remaining: factCheck.estimatedSecondsRemaining,
    created_at: factCheck.createdAt.toISOString(),
    updated_at: factCheck.statusUpdatedAt.toISOString()
  });
});
```

---

### Step 5: Update POST /fact-check to Return submission_id

**Python (Flask) Example:**
```python
@app.route('/fact-check', methods=['POST'])
def fact_check():
    data = request.get_json()
    user_id = request.args.get('userId')
    session_id = request.args.get('sessionId')
    
    # Validate
    if not validate_session(user_id, session_id):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    instagram_url = data.get('link')
    submission_id = data.get('submission_id') or str(uuid.uuid4())
    
    # Create fact check record
    fact_check = FactCheck(
        submission_id=submission_id,
        link=instagram_url,
        uploaded_by=user_id,
        processing_status='submitting',
        progress_percentage=10,
        current_stage='Submitting your reel',
        estimated_seconds_remaining=90
    )
    db.session.add(fact_check)
    db.session.commit()
    
    # Start async processing
    process_fact_check_async.delay(submission_id, instagram_url)
    
    # Return immediately with submission_id
    return jsonify({
        'submission_id': submission_id,
        'status': 'processing',
        'progress_percentage': 10,
        'message': f'Fact-check started, poll /api/submission-status/{submission_id} for updates'
    }), 202
```

---

## iOS App Polling Behavior

### Polling Configuration
- **Interval:** Every 3 seconds
- **Timeout:** 60 polls × 3s = 3 minutes maximum
- **Error handling:** 5 second delay on errors, then retry
- **Completion:** Stops when status == "completed" or "failed"

### Expected Request Volume
- **Per submission:** ~20-30 requests (90s ÷ 3s polling interval)
- **Concurrent submissions:** Support at least 10 simultaneous processing jobs
- **Total QPS:** With 10 concurrent submissions: ~3-5 requests/second

### Performance Requirements
- **Response time:** <200ms per status check
- **Database load:** Use indexes on `submission_id` for fast lookups
- **Caching:** Consider caching status for 1-2 seconds if needed

---

## Testing Guide

### Test Case 1: Happy Path
```bash
# Submit fact-check
curl -X POST "http://localhost:5001/fact-check?userId=test&sessionId=abc" \
  -H "Content-Type: application/json" \
  -d '{"link": "https://instagram.com/reel/test123", "submission_id": "test-001"}'

# Response:
# { "submission_id": "test-001", "status": "processing", "progress_percentage": 10 }

# Poll for status (repeat every 3s)
curl "http://localhost:5001/api/submission-status/test-001?userId=test&sessionId=abc"

# Response progresses:
# { "status": "downloading", "progress_percentage": 15, ... }
# { "status": "analyzing", "progress_percentage": 55, ... }
# { "status": "completed", "progress_percentage": 100, ... }
```

### Test Case 2: Not Found
```bash
curl "http://localhost:5001/api/submission-status/nonexistent?userId=test&sessionId=abc"
# Expected: 404 with {"error": "Submission not found"}
```

### Test Case 3: Unauthorized
```bash
curl "http://localhost:5001/api/submission-status/test-001?userId=wrong&sessionId=bad"
# Expected: 401 with {"error": "Invalid credentials"}
```

---

## Implementation Checklist

### Phase 1: Core Implementation (Required)
- [ ] Add progress tracking columns to database
- [ ] Create `update_submission_progress()` helper function
- [ ] Implement `GET /api/submission-status/:id` endpoint
- [ ] Update `POST /fact-check` to return `submission_id`
- [ ] Add progress updates to processing pipeline (minimum 5 checkpoints)
- [ ] Test with iOS app polling

### Phase 2: Optimization (Recommended)
- [ ] Add database indexes for fast lookups
- [ ] Implement request caching (1-2 second TTL)
- [ ] Add metrics/logging for progress tracking
- [ ] Set up monitoring for slow status checks (>200ms)

### Phase 3: Advanced Features (Optional)
- [ ] WebSocket support for real-time push updates
- [ ] APNs integration for push notifications
- [ ] Adaptive time estimation based on video length
- [ ] Progress analytics and reporting

---

## Common Pitfalls & Solutions

### Issue 1: Progress Not Updating
**Symptom:** iOS app shows stuck progress  
**Solution:** Ensure `update_submission_progress()` is called **before** each major processing step, not after

### Issue 2: Slow Status Checks (>500ms)
**Symptom:** Polling causes performance issues  
**Solution:** Add index on `submission_id` column, consider caching

### Issue 3: Inaccurate Time Estimates
**Symptom:** "5s remaining" but takes 30s  
**Solution:** Calculate estimates based on actual average processing times, not hardcoded values

### Issue 4: Completed Status Not Detected
**Symptom:** iOS keeps polling forever  
**Solution:** Ensure final progress update sets status='completed' and progress=100

---

## Support & Questions

For implementation questions or issues:
1. Review the iOS app logs for polling behavior
2. Check backend logs for status update calls
3. Verify database schema matches specification
4. Test with curl commands from Testing Guide section

**iOS App Configuration:**
- Polling endpoint: `Config.Endpoints.submissionStatus` (`/api/submission-status`)
- Polling interval: 3 seconds
- Timeout: 3 minutes (60 polls)

---

## Appendix: Complete Example Implementation

See `examples/` directory for complete working implementations:
- `examples/python_flask/` - Flask + SQLAlchemy
- `examples/nodejs_express/` - Express + Sequelize
- `examples/django/` - Django + DRF

---

**Document Version:** 1.0  
**Last Updated:** February 19, 2026  
**Next Review:** After initial implementation and testing
