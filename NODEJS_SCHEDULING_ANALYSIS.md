# Node.js tulkka-api Scheduling Logic Analysis

## Overview

This document analyzes the exact scheduling logic used in the Node.js `tulkka-api` backend that must be replicated in the matching engine to avoid double-bookings and mismatched data.

---

## 1. One-Time Availability Calendar (Trial Lessons)

### File: `teacher-availability.controller.js` - `getTimeSlotAvailability()`

**Location:** Lines 381-538

### 3-Layer Conflict Detection

#### Layer 1: Teacher's Configured Schedule
```javascript
// Parse static JSON schedule from teacher_availability table
const dayOfWeek = utcDate.format('ddd').toLowerCase();
const daySchedule = JSON.parse(teacher.availability[dayOfWeek]);
// daySchedule format: {"17:00": true, "17:30": true, ...}
```

#### Layer 2: Approved Holidays
```javascript
// Fetch approved holidays for the date range
const holiday = teacher.holidays?.find(holiday => {
    const holidayStart = moment.utc(holiday.form_date);
    const holidayEnd = moment.utc(holiday.to_date);
    return slotStartUTC.isBefore(holidayEnd) && 
           slotEndUTC.isAfter(holidayStart);
});
```

#### Layer 3: Existing Classes
```javascript
// Check for class conflicts using SQL BETWEEN logic
const conflictingClass = existingClasses.find(cls => {
    const classStart = moment.utc(cls.meeting_start);
    const classEnd = moment.utc(cls.meeting_end);
    return slotStartUTC.isBefore(classEnd) &&
           slotEndUTC.isAfter(classStart);
});
```

### Timezone Conversion
```javascript
// Convert student timezone to teacher timezone
const utcStartTime = moment.tz(start_time, studentTimezone).utc();
const utcEndTime = moment.tz(end_time, studentTimezone).utc();
```

### Key Logic
- Generates 30-minute slots for entire day in UTC
- Checks each slot against all 3 layers
- Returns slot with availability status and reason if unavailable

---

## 2. Recurring Availability Calendar (Subscriptions)

### File: `monthly-class.controller.js` - `getWeeklyTeacherAvailability()`

**Location:** Lines 422-883

### Occupancy Calculation

#### Total Slots Calculation
```javascript
const calculateTeacherTotalSlots = (teacherId, teacherAvailability) => {
    let totalSlots = 0;
    const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    daysOfWeek.forEach(day => {
        const dayKey = day.toLowerCase().substring(0, 3);
        
        if (teacherAvailability && teacherAvailability[dayKey]) {
            const dayAvailability = JSON.parse(teacherAvailability[dayKey] || '{}');
            
            // Count all available time slots for this day
            for (const timeSlot in dayAvailability) {
                if (dayAvailability[timeSlot] === true) {
                    totalSlots++;
                }
            }
        }
    });
    
    return totalSlots;
};
```

#### Booked Slots Calculation
```javascript
// Each regular class occupies slots based on duration
const duration = getLessonDurationFromSubscription(regClass.Student);
const slotsToSpan = Math.ceil(duration / 30);

// Count booked slots for this teacher
teacherBookedSlotsCount.set(regClass.teacher_id, currentCount + slotsToSpan);
```

### Lesson Duration from Subscription
```javascript
const getLessonDurationFromSubscription = (student) => {
    const defaultDuration = 30;
    
    if (!student || !student.UserSubscriptions || student.UserSubscriptions.length === 0) {
        return defaultDuration;
    }
    
    const subscription = student.UserSubscriptions[0];
    const lessonMinutes = subscription.lesson_min;
    
    if (!lessonMinutes || lessonMinutes <= 0) {
        return defaultDuration;
    }
    
    return lessonMinutes;
};
```

### Timezone Conversion
```javascript
const convertTimeToTimezone = (timeString, fromTimezone, toTimezone) => {
    if (!timeString || fromTimezone === toTimezone) {
        return timeString;
    }

    const today = momentTz().tz(fromTimezone);
    const [hours, minutes] = timeString.split(':').map(Number);
    
    const sourceTime = today.clone().set({
        hour: hours,
        minute: minutes,
        second: 0,
        millisecond: 0
    });

    const targetTime = sourceTime.clone().tz(toTimezone);
    return targetTime.format('HH:mm');
};
```

---

## 3. Recurring Class Availability Check

### File: `monthly-class.controller.js` - `checkClassAvailability()`

**Location:** Lines 891-1039

### 4-Week Pattern Check
```javascript
// Calculate next 4 occurrences of this day and time
const occurrences = getNextOccurrences(day, time, 4);

// Check each occurrence
for (const occurrence of occurrences) {
    const startTime = moment.utc(occurrence);
    const endTime = moment.utc(occurrence).add(classDuration, 'minutes');
    
    // Skip teacher availability check - allows bookings regardless
    
    // Check for holiday conflicts
    const isHoliday = teacherHolidays.some(holiday => {
        const holidayStart = moment.utc(holiday.form_date);
        const holidayEnd = moment.utc(holiday.to_date);
        return startTime.isBetween(holidayStart, holidayEnd, null, '[]');
    });
    
    // Check for existing class conflicts
    const conflictingClass = await Class.findOne({
        where: {
            teacher_id,
            [Op.or]: [
                {
                    meeting_start: {
                        [Op.between]: [startTime.format(), endTime.format()]
                    }
                },
                {
                    meeting_end: {
                        [Op.between]: [startTime.format(), endTime.format()]
                    }
                }
            ],
            status: {
                [Op.notIn]: ['canceled', 'rejected']
            }
        }
    });
}
```

### Key Logic
- Checks 4 consecutive weeks for availability
- Does NOT check teacher's configured availability (allows bookings regardless)
- Only checks holidays and existing class conflicts
- Uses SQL BETWEEN logic for time overlap detection

---

## 4. Teacher Capacity & Active Students

### File: `regular-class-activity.controller.js` - `getRegularClassActivity()`

**Location:** Lines 13-249

### Active Student Calculation
```javascript
// Get current active students assigned to this teacher
const activeStudents = await User.count({
    include: [
        {
            model: RegularClass,
            as: 'StudentRegularClasses',
            required: true,
            where: {
                teacher_id: teacher.id
            }
        },
        {
            model: UserSubscriptionDetails,
            as: 'UserSubscriptions',
            required: true,
            where: {
                status: 'active'
            }
        }
    ],
    distinct: true
});
```

### Key Logic
- Active students are those who:
  1. Have a regular class with the teacher
  2. Have an active subscription (status='active' in user_subscription_details)
- Uses complex SQL with ROW_NUMBER() for accurate counting
- Only counts students with active subscriptions, not just regular classes

---

## 5. Teacher Performance Metrics

### File: `teacher.controller.js` - `getTeacherMetrics()`

**Location:** Lines 2206-2263

### Trial Conversion Rate Calculation
```javascript
// 1️⃣ Fetch trial classes (completed, missed, ended) EXCLUDING cancelled
const trialClasses = await Class.findAll({
    where: {
        teacher_id: teacherId,
        is_trial: true,
        demo_class_id: { [Op.ne]: null },
        meeting_start: { [Op.between]: [start, end] },
        status: { [Op.ne]: 'cancelled' }
    },
    include: [
        {
            model: TrialClassRegistration,
            as: 'linkedTrialRegistration',
            attributes: ['id', 'email', 'meeting_start'],
            required: false
        }
    ]
});

// 2️⃣ Conversions: subscription within 30 days
const conversions = await UserSubscriptionDetails.findAll({
    where: {
        created_at: {
            [Op.between]: [
                start,
                moment(end).add(30, "days").toDate()
            ]
        }
    },
    include: [
        {
            model: User,
            as: 'SubscriptionUser',
            where: {
                role_name: 'user',
                status: 'active'
            }
        }
    ]
});
```

### Key Logic
- Trial conversion = subscriptions created within 30 days of trial
- Only counts trials with status != 'cancelled'
- Uses parallel execution for performance

---

## 6. Data Models

### teacherAvailability Model
**File:** `src/models/teacherAvailability.js`

```javascript
const TeacherAvailability = sequelize.define('teacher_availability', {
    id: DataTypes.BIGINT.UNSIGNED,
    user_id: DataTypes.BIGINT.UNSIGNED,
    mon: { type: DataTypes.TEXT, defaultValue: '{}' },  // JSON: {"17:00": true, "17:30": true, ...}
    tue: { type: DataTypes.TEXT, defaultValue: '{}' },
    wed: { type: DataTypes.TEXT, defaultValue: '{}' },
    thu: { type: DataTypes.TEXT, defaultValue: '{}' },
    fri: { type: DataTypes.TEXT, defaultValue: '{}' },
    sat: { type: DataTypes.TEXT, defaultValue: '{}' },
    sun: { type: DataTypes.TEXT, defaultValue: '{}' }
});
```

### Key Points
- Each day stores JSON object with time slots as keys
- Example: `{"17:00": true, "17:30": true, "18:00": true}`
- Uses `TEXT` type with JSON parsing

---

## 7. Critical Logic Summary

### Trial Lesson Availability (One-Time)
1. Parse date in UTC
2. Get teacher's configured schedule (JSON per day)
3. Generate 30-minute slots for entire day
4. For each slot, check:
   - Is slot in teacher's configured schedule?
   - Is teacher on approved holiday?
   - Does teacher have existing class?
5. Return available slots with reasons

### Subscription Availability (Recurring)
1. Calculate teacher's total available slots (30-min blocks)
2. Calculate booked slots from regular classes (duration-based)
3. Calculate occupancy rate = booked / total
4. Filter teachers by occupancy threshold (default 85%)
5. For each slot, check:
   - Is teacher on holiday?
   - Does teacher have existing class?
   - (Does NOT check teacher's configured availability)

### Active Student Count
1. Join users → regular_class → user_subscription_details
2. Only count students with status='active' in user_subscription_details
3. Use DISTINCT to avoid double-counting

### Performance Metrics
1. Trial conversion = subscriptions within 30 days of trial
2. Exclude cancelled trials
3. Use parallel execution for performance

---

## 8. Required Schema Updates

### users.js Model - Teacher Role Fields
```javascript
// Add these fields to the teacher role definition
trial_enabled: { type: DataTypes.BOOLEAN, defaultValue: true },
recurring_enabled: { type: DataTypes.BOOLEAN, defaultValue: true },
max_students_capacity: { type: DataTypes.INTEGER, defaultValue: 20 },
teacher_tags: { type: DataTypes.JSON, defaultValue: [] },
age_min: { type: DataTypes.INTEGER, defaultValue: 5 },
age_max: { type: DataTypes.INTEGER, defaultValue: 18 },
teacher_trial_priority: { type: DataTypes.ENUM('high', 'normal', 'low', 'disabled'), defaultValue: 'normal' }
```

---

## 9. Integration Options

### Option 1: Replicate SQL in Matching Engine
- Port SQL queries from Node.js controllers to Python
- Implement 3-layer conflict detection
- Handle timezone conversions with pytz/moment-timezone equivalent

### Option 2: Build Data Bridges
- Create GET endpoints in tulkka-api that do heavy lifting
- Matching engine calls these endpoints via HTTP
- Returns raw JSON matrices for matching engine to process

---

## 10. Key Differences Between Trial and Subscription

| Aspect | Trial (One-Time) | Subscription (Recurring) |
|--------|------------------|---------------------------|
| Teacher Schedule Check | YES - must be configured | NO - allows bookings regardless |
| Duration | Fixed 25-30 minutes | Variable (from subscription) |
| Holiday Check | YES | YES |
| Existing Class Check | YES | YES |
| Timeframe | Single date | 4-week pattern |
| Occupancy Threshold | 85% default | 85% default |

---

## 11. Critical Gotchas

1. **Timezone Handling**: Always convert to UTC for storage and comparison
2. **Duration Expansion**: Longer classes expand collision window (e.g., 55min class spans 2 slots)
3. **Subscription Status**: Only count students with active subscriptions, not just regular classes
4. **Trial Exclusion**: Exclude cancelled trials from conversion calculation
5. **JSON Parsing**: Teacher availability stored as JSON strings, need to parse
6. **SQL BETWEEN**: Use `isBefore(classEnd) && isAfter(classStart)` for overlap detection
7. **30-Minute Slots**: All availability calculations use 30-minute blocks
8. **4-Week Pattern**: Recurring availability checks 4 consecutive weeks
9. **Holiday Status**: Only approved holidays (status='approved') are considered
10. **Class Status**: Exclude 'canceled' and 'rejected' from conflict checks

---

## 12. Recommended Implementation Strategy

### Phase 1: Core Availability Logic
1. Implement 3-layer conflict detection for trials
2. Implement 4-week pattern check for subscriptions
3. Handle timezone conversions properly

### Phase 2: Performance Metrics
1. Calculate trial conversion rates
2. Calculate student retention
3. Implement parallel execution

### Phase 3: Capacity Management
1. Calculate active students correctly
2. Implement occupancy rate filtering
3. Handle duration-based slot counting

### Phase 4: Integration
1. Update Node.js models with new fields
2. Create data bridges or replicate SQL
3. Test with real data

---

## 13. Testing Checklist

- [ ] Trial availability matches Node.js logic exactly
- [ ] Subscription availability matches Node.js logic exactly
- [ ] Timezone conversions are correct
- [ ] Holiday detection works
- [ ] Class conflict detection works
- [ ] Active student count is accurate
- [ ] Trial conversion rate is accurate
- [ ] No double-bookings occur
- [ ] Performance is acceptable (<5 seconds)
- [ ] Edge cases handled (overlapping slots, midnight boundaries, etc.)

---

## 14. Architecture: Node.js Scheduling & Worker Engine

### 14.1 The Challenge
The matching engine is written in Python (for fast matrix operations, pandas, numpy, and ML/heuristic routing). However, the main backend is Node.js. 
When a student requests a match, or when the system periodically runs bulk matching for pending subscriptions, Node.js needs to invoke this Python logic asynchronously.

### 14.2 Tool Selection: BullMQ vs. Agenda

For scheduling the matching tasks in Node.js, we have two primary options:

| Feature | BullMQ (Redis-based) | Agenda (MongoDB-based) |
|---------|----------------------|-----------------------|
| **Persistence** | Redis | MongoDB |
| **Speed** | Extremely fast (in-memory) | Slower (disk/DB bound) |
| **Complex Flows** | Excellent (Parent/Child jobs) | Basic |
| **Concurrency** | High (built for heavy job processing) | Moderate |
| **Recommendation** | **Winner** | Alternative if Redis is unavailable |

**Why BullMQ?** Matching can be a CPU-intensive background task. BullMQ provides robust retries, rate-limiting, sandboxed processes, and a clean UI (via Bull-Board). 

### 14.3 Execution Strategy: child_process vs. Microservice

How should Node.js run the Python matching engine?

**Option A: `child_process.spawn` (Monolith/Simple)**
- Node.js spawns a Python script directly: `spawn('python', ['matching_engine.py', '--data', 'input.json'])`
- **Pros:** Simple to set up, no extra networking, single deployment.
- **Cons:** Blocks the local server's CPU if not sandboxed properly. Python startup time (loading pandas/ML models) happens on *every* run.

**Option B: Python Microservice (FastAPI/Flask) - Recommended**
- Python engine runs as a separate persistent service (e.g., FastAPI).
- Node.js sends an HTTP POST request to trigger matching.
- **Pros:** 
  - Python models and libraries are loaded into memory once (huge speedup!).
  - Can be scaled independently of the Node.js backend.
  - Clean HTTP/JSON interface.
- **Cons:** Requires managing a second deployment (the Python service).

### 14.4 Recommended Architecture Flow

1. **Trigger:** A Cron job (BullMQ repeatable job) runs every 1 hour OR a user requests a trial match instantly.
2. **Data Prep (Node.js):**
   - Node.js fetches all pending students and eligible teachers from the MySQL database.
   - Node.js executes the SQL representations of layers 1-3 (existing classes, holidays, configs) to generate initial raw matrices. 
3. **Queueing (BullMQ):**
   - Node.js pushes a `process_matching` job to BullMQ containing the raw JSON data.
4. **Execution (Worker):**
   - A BullMQ worker picks up the job.
   - It sends an HTTP POST with the JSON data to the **Python FastAPI Matching Engine**.
   - The Python engine runs the Hungarian algorithm, heuristic scoring, and returns the optimal `[(student_id, teacher_id, time_slot)]` pairs.
5. **Fulfillment (Node.js):**
   - The BullMQ worker receives the matches.
   - It creates the `Class` and `TrialClassRegistration` records in the MySQL database via Sequelize.
   - Sends notification emails to the teacher and student.

### 14.5 Data Bridge Payload Example

**Node.js -> Python (Request)**
```json
{
  "students": [
    { "id": 1, "timezone": "America/New_York", "type": "trial", "age": 10 }
  ],
  "teachers": [
    { "id": 101, "timezone": "Asia/Kolkata", "trial_enabled": true, "historical_conversion_rate": 0.85 }
  ],
  "availability_matrix": [
    { "teacher_id": 101, "utc_slot": "2023-11-20T17:00:00Z", "available": true }
  ]
}
```

**Python -> Node.js (Response)**
```json
{
  "matches": [
    { "student_id": 1, "teacher_id": 101, "utc_slot": "2023-11-20T17:00:00Z", "score": 0.92 }
  ],
  "unmatched_students": []
}
```
