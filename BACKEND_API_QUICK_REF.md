# Quick Reference: Backend API Integration

## Endpoint: GET /api/submission-status/:id

### Request
```
GET http://YOUR_BACKEND/api/submission-status/{submission_id}?userId=X&sessionId=Y
```

### Response (JSON)
```json
{
  "submission_id": "uuid-string",
  "status": "analyzing",
  "progress_percentage": 65,
  "current_stage": "Analyzing video content",
  "estimated_seconds_remaining": 35,
  "created_at": "2026-02-19T10:30:00Z",
  "updated_at": "2026-02-19T10:31:05Z"
}
```

### Status Values
| Status | Progress | Description |
|--------|----------|-------------|
| `submitting` | 5-10% | Initial request |
| `downloading` | 10-20% | Getting video |
| `processing` | 20-40% | Extracting data |
| `analyzing` | 40-70% | Analyzing content |
| `fact_checking` | 70-95% | Verifying claims |
| `completed` | 100% | Done |
| `failed` | 0% | Error occurred |

---

## Endpoint: POST /fact-check (Updated)

### Response Should Include
```json
{
  "submission_id": "uuid-string",
  "status": "processing",
  "progress_percentage": 10,
  "message": "Fact-check started"
}
```

---

## Database Changes Required

```sql
ALTER TABLE fact_checks ADD COLUMN
  processing_status VARCHAR(50) DEFAULT 'submitting',
  progress_percentage INTEGER DEFAULT 0,
  current_stage VARCHAR(255) DEFAULT 'Submitting',
  estimated_seconds_remaining INTEGER DEFAULT 90,
  status_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX idx_submission_status 
  ON fact_checks(submission_id, processing_status);
```

---

## Progress Update Example (Python)

```python
def update_submission_progress(submission_id, status, progress, stage, est_time):
    fact_check = FactCheck.query.filter_by(submission_id=submission_id).first()
    fact_check.processing_status = status
    fact_check.progress_percentage = progress
    fact_check.current_stage = stage
    fact_check.estimated_seconds_remaining = est_time
    db.session.commit()

# In your processing pipeline:
update_submission_progress(id, 'downloading', 15, 'Downloading video', 75)
update_submission_progress(id, 'analyzing', 55, 'Analyzing content', 35)
update_submission_progress(id, 'completed', 100, 'Complete', 0)
```

---

## iOS App Behavior

- **Polling interval:** Every 3 seconds
- **Stops when:** status == "completed" or "failed"
- **Timeout:** 3 minutes (60 polls)
- **Error handling:** Retries with 5s delay

---

## Testing

```bash
# Submit
curl -X POST "http://localhost:5001/fact-check?userId=test&sessionId=abc" \
  -H "Content-Type: application/json" \
  -d '{"link": "https://instagram.com/reel/test", "submission_id": "test-001"}'

# Poll (repeat every 3s)
curl "http://localhost:5001/api/submission-status/test-001?userId=test&sessionId=abc"
```

---

**Full Documentation:** See `BACKEND_REALTIME_PROGRESS_API.md`
