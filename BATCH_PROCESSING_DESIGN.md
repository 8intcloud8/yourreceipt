# Batch Receipt Processing Design

## Overview
Allow users to upload and process multiple receipts in sequence, reviewing and editing each one before moving to the next.

## Design Approach

### 1. Upload Queue System
- Allow users to select/capture multiple receipts at once
- Store them in a queue (list of images)
- Show a counter like "Processing 1 of 5"

### 2. UI Flow
```
[Select Multiple Receipts Button] → Queue created
↓
Display first receipt → User reviews/edits → Press Submit
↓
Automatically load next receipt → User reviews/edits → Press Submit
↓
Repeat until queue is empty
↓
Show summary: "5 receipts processed"
```

### 3. Key Features

#### Upload Phase
- Button: "Upload Multiple Receipts" (file picker allows multiple selection)
- Show thumbnails of queued receipts (like a carousel at the top)
- Display: "5 receipts queued"

#### Processing Phase
- Current receipt shows in main view (like now)
- Progress indicator: "Receipt 2 of 5"
- Submit button saves current receipt and auto-loads next one
- Skip button to skip current receipt
- Navigation: Previous/Next buttons to jump between receipts in queue

#### State Management
```dart
List<Uint8List> _receiptQueue = [];
int _currentReceiptIndex = 0;
List<Map<String, dynamic>> _processedReceipts = [];
```

### 4. User Experience

#### Top Bar
```
[← Previous] Receipt 2 of 5 [Next →] [Skip]
```

#### Thumbnail Strip (optional)
```
[✓ Receipt 1] [• Receipt 2] [Receipt 3] [Receipt 4] [Receipt 5]
```
- ✓ = processed
- • = current
- gray = pending

#### Submit Button Behavior
- Saves current receipt data
- Marks as processed
- Auto-loads next receipt
- If last receipt → Show "All done! 5 receipts processed"

### 5. Additional Features

#### Bulk Actions
- "Process All Automatically" - OCR all at once, then review one by one
- "Export All" - Download all processed receipts as CSV/JSON

#### Error Handling
- If OCR fails on one receipt, mark it and continue to next
- Allow user to retry failed receipts later

#### Data Persistence
- Save queue to localStorage so user doesn't lose progress if they refresh

## Implementation Notes

### Frontend Changes
1. Add file picker with multiple selection support
2. Create queue management state
3. Add navigation controls (Previous/Next/Skip)
4. Add progress indicator
5. Modify Submit button to auto-advance to next receipt
6. Add thumbnail preview strip

### Backend Changes
- No changes needed - existing API handles single receipt processing
- Queue processing happens entirely on frontend

### User Workflow
1. User clicks "Upload Multiple Receipts"
2. Selects 5 receipt images
3. App shows "5 receipts queued"
4. First receipt loads automatically and OCR processes
5. User reviews/edits data
6. User clicks Submit
7. Receipt 1 saved, Receipt 2 loads automatically
8. Repeat steps 5-7 for all receipts
9. After last receipt submitted, show summary screen

## Benefits
- Faster workflow for users with many receipts
- Reduces repetitive clicking
- Better user experience for bulk processing
- No need to re-upload between receipts
