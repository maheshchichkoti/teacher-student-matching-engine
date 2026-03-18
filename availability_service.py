"""
Availability Service - Replicates Node.js tulkka-api scheduling logic

This module implements the exact availability calculation flows from the Node.js backend:
1. One-Time Availability (Trial Lessons) - 3-layer conflict detection
2. Recurring Availability (Subscriptions) - 4-week pattern check
3. Teacher Capacity calculation
4. Timezone conversion utilities
"""

from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import pytz
from psycopg2.extensions import connection as Connection


class AvailabilityService:
    """Service for calculating teacher availability matching Node.js logic"""

    def __init__(self, conn: Connection):
        self.conn = conn

    def get_trial_availability(
        self, teacher_id: int, date: str, student_timezone: str = "Asia/Jerusalem"
    ) -> List[Dict[str, Any]]:
        """
        Get one-time availability for trial lessons.
        Replicates getTimeSlotAvailability() from teacher-availability.controller.js

        3-Layer Conflict Detection:
        1. Teacher's configured schedule (JSON per day)
        2. Approved holidays (TeacherHoliday table)
        3. Existing classes (Classes table with status not in ['canceled', 'rejected'])

        Returns list of 25-minute slots with availability status in student timezone
        """
        # Parse date in UTC
        try:
            utc_date = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=pytz.UTC)
        except ValueError:
            return []

        utc_start = utc_date.replace(hour=0, minute=0, second=0, microsecond=0)
        utc_end = utc_date.replace(hour=23, minute=59, second=59, microsecond=999999)

        # Get teacher with availability and holidays
        teacher = self._get_teacher_with_availability(teacher_id)
        if not teacher:
            return []

        # Get existing classes for this date
        existing_classes = self._get_existing_classes(teacher_id, utc_start, utc_end)

        # Get teacher holidays
        holidays = self._get_teacher_holidays(teacher_id, utc_start, utc_end)

        # Get student timezone
        student_tz = pytz.timezone(student_timezone)

        # Generate 25-minute slots on 5-minute grid (trial lesson duration)
        time_slots = []
        day_of_week = utc_date.strftime("%a").lower()

        for hour in range(24):
            for minute in range(0, 60, 5):  # 5-minute grid
                slot_start = utc_date.replace(
                    hour=hour, minute=minute, second=0, microsecond=0
                )
                slot_end = slot_start + timedelta(
                    minutes=25
                )  # Trial lesson is 25 minutes

                # Skip if slot end doesn't align to 5-minute grid
                if slot_end.minute % 5 != 0:
                    continue

                time_key = slot_start.strftime("%H:%M")

                slot_info = {
                    "start": slot_start.astimezone(student_tz).isoformat(),
                    "end": slot_end.astimezone(student_tz).isoformat(),
                    "is_available": False,
                    "message": "",
                }

                # Layer 1: Check teacher's configured schedule
                if not teacher.get("availability") or not teacher["availability"].get(
                    day_of_week
                ):
                    slot_info["message"] = "Teacher is not available on this day"
                    time_slots.append(slot_info)
                    continue

                day_schedule = teacher["availability"][day_of_week]
                if not day_schedule.get(time_key):
                    slot_info["message"] = f"Teacher is unavailable at {time_key}"
                    time_slots.append(slot_info)
                    continue

                # Layer 2: Check if teacher is on holiday
                holiday = self._check_holiday_conflict(slot_start, slot_end, holidays)
                if holiday:
                    slot_info["message"] = "Teacher is on holiday"
                    time_slots.append(slot_info)
                    continue

                # Layer 3: Check for class conflicts
                conflicting_class = self._check_class_conflict(
                    slot_start, slot_end, existing_classes
                )
                if conflicting_class:
                    slot_info["message"] = (
                        f"Teacher has a class with {conflicting_class.get('student_name', 'a student')}"
                    )
                    time_slots.append(slot_info)
                    continue

                # Slot is available
                slot_info["is_available"] = True
                slot_info["message"] = ""
                time_slots.append(slot_info)

        return time_slots

    def get_recurring_availability(
        self,
        teacher_id: int,
        day: str,
        time: str,
        weeks: int = 4,
        lesson_duration_minutes: int = 60,
    ) -> List[Dict[str, Any]]:
        """
        Get recurring availability for subscriptions.
        Replicates checkClassAvailability() from monthly-class.controller.js

        Checks 4-week pattern for availability (Spec-aligned):
        - Verifies the teacher has recurring availability for the requested day+time
          using `clean.teacher_availability` (via `_get_teacher_with_availability`).
        - Checks holiday conflicts
        - Checks existing class conflicts
        """
        teacher = self._get_teacher_with_availability(teacher_id)
        if not teacher:
            return []

        # Get teacher holidays
        holidays = self._get_teacher_holidays(teacher_id)

        # Schedule check (recurring calendar)
        day_key = self._normalize_day_key(day)
        if not day_key:
            return []
        if not teacher.get("availability") or not teacher["availability"].get(day_key):
            return []

        # Teacher availability is stored as 30-minute blocks.
        # For a lesson duration > 30, ensure all consecutive 30-minute blocks are available.
        required_slots = max(
            1, (int(lesson_duration_minutes) + 29) // 30
        )  # ceil(duration/30)
        try:
            start_h, start_m = map(int, time.split(":", 1))
            start_minutes = start_h * 60 + start_m
        except Exception:
            return []

        for i in range(required_slots):
            slot_minutes = start_minutes + (i * 30)
            if slot_minutes >= 24 * 60:
                return []
            hh, mm = divmod(slot_minutes, 60)
            time_key_i = f"{hh:02d}:{mm:02d}"
            if not teacher["availability"][day_key].get(time_key_i):
                return []

        # Calculate next N occurrences (UTC)
        occurrences = self._get_next_occurrences(day_key, time, weeks)

        results = []

        for occurrence in occurrences:
            start_time = occurrence
            end_time = occurrence + timedelta(minutes=int(lesson_duration_minutes))
            date_str = start_time.strftime("%Y-%m-%d")
            day_name = start_time.strftime("%A")

            availability_info = {
                "day": day_name,
                "time": time,
                "date": date_str,
                "iso_datetime": start_time.isoformat(),
                "end_datetime": end_time.isoformat(),
                "available": True,
                "unavailability_reason": None,
            }

            # Check for holiday conflicts
            is_holiday = self._check_holiday_conflict(start_time, end_time, holidays)
            if is_holiday:
                availability_info["available"] = False
                availability_info["unavailability_reason"] = "Teacher on holiday"

            # Check for existing class conflicts
            conflicting_class = self._check_class_conflict_db(
                teacher_id, start_time, end_time
            )
            if conflicting_class:
                availability_info["available"] = False
                availability_info["unavailability_reason"] = (
                    "Teacher has another class scheduled"
                )

            results.append(availability_info)

        return results

    def calculate_teacher_occupancy(
        self, teacher_id: int, occupancy_threshold: float = 85.0
    ) -> Dict[str, Any]:
        """
        Calculate teacher occupancy rate.
        Replicates getWeeklyTeacherAvailability() logic from monthly-class.controller.js

        Returns:
            {
                'total_slots': int,
                'booked_slots': int,
                'occupancy_rate': float,
                'below_threshold': bool
            }
        """
        # Get teacher's availability
        teacher = self._get_teacher_with_availability(teacher_id)
        if not teacher:
            return {
                "total_slots": 0,
                "booked_slots": 0,
                "occupancy_rate": 0.0,
                "below_threshold": False,
            }

        # Calculate total available slots (30-minute blocks)
        total_slots = self._calculate_total_slots(teacher["availability"])

        # Calculate booked slots from regular classes
        booked_slots = self._calculate_booked_slots(teacher_id)

        # Calculate occupancy rate
        occupancy_rate = (booked_slots / total_slots * 100) if total_slots > 0 else 0.0

        return {
            "total_slots": total_slots,
            "booked_slots": booked_slots,
            "occupancy_rate": round(occupancy_rate, 2),
            "below_threshold": occupancy_rate <= occupancy_threshold,
        }

    def get_active_student_count(self, teacher_id: int) -> int:
        """
        Get count of active students for a teacher.
        Replicates getRegularClassActivity() logic from regular-class-activity.controller.js

        Active students are those who:
        1. Have a regular class with the teacher
        2. Have an active subscription (status='active' in user_subscription_details)
        """
        query = """
            WITH active_subscriptions AS (
                SELECT subscription_id, owner_student_id
                FROM clean.subscriptions
                WHERE status = 'active'
            ),
            active_subscription_students AS (
                SELECT DISTINCT
                    c.teacher_id,
                    COALESCE(sm.student_id, s.owner_student_id, c.student_id) AS student_id
                FROM clean.classes c
                JOIN active_subscriptions s
                  ON s.subscription_id = c.subscription_id
                LEFT JOIN clean.subscription_members sm
                  ON sm.subscription_id = s.subscription_id
                 AND sm.status = 'active'
                WHERE c.teacher_id = %s
                  AND c.lifecycle_status IN ('confirmed', 'in_progress', 'completed_raw', 'completed_ai', 'verified')
            ),
            active_non_subscription_students AS (
                SELECT DISTINCT c.teacher_id, c.student_id
                FROM clean.classes c
                WHERE c.teacher_id = %s
                  AND c.subscription_id IS NULL
                  AND c.lifecycle_status IN ('confirmed', 'in_progress')
            ),
            active_students AS (
                SELECT teacher_id, student_id FROM active_subscription_students
                UNION
                SELECT teacher_id, student_id FROM active_non_subscription_students
            )
            SELECT COUNT(DISTINCT student_id) AS count
            FROM active_students
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id, teacher_id))
        result = cur.fetchone()
        cur.close()

        return result[0] if result else 0

    def _get_trial_filter_sql(self, alias: str = "c") -> str:
        qualifier = f"{alias}." if alias else ""
        cur = self.conn.cursor()
        cur.execute(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
              AND column_name = %s
            LIMIT 1
            """,
            ("clean", "classes", "is_trial"),
        )
        has_is_trial = cur.fetchone() is not None
        cur.close()
        if has_is_trial:
            return f"COALESCE(LOWER(({qualifier}is_trial)::text), '0') IN ('1', 't', 'true')"
        return f"{qualifier}subscription_id IS NULL"

    def get_trial_conversion_rate(
        self, teacher_id: int, period_days: int = 30
    ) -> Dict[str, Any]:
        """
        Calculate trial conversion rate for a teacher using analytics schema.
        Replicates getTeacherMetrics() logic from teacher.controller.js

        Returns:
            {
                'total_trials': int,
                'conversions': int,
                'conversion_rate': float
            }
        """
        # Get trial classes in period
        end_date = datetime.now(pytz.UTC)
        start_date = end_date - timedelta(days=period_days)
        trial_filter = self._get_trial_filter_sql("c")

        query = f"""
            SELECT COUNT(*) AS count
            FROM clean.classes c
            WHERE c.teacher_id = %s
              AND {trial_filter}
              AND c.meeting_start BETWEEN %s AND %s
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id, start_date, end_date))
        result = cur.fetchone()
        total_trials = result[0] if result else 0
        cur.close()

        if total_trials == 0:
            return {"total_trials": 0, "conversions": 0, "conversion_rate": 0.0}

        # Get conversions using funnel stage
        query = f"""
            SELECT COUNT(DISTINCT c.student_id) AS count
            FROM clean.classes c
            INNER JOIN analytics.leads l
              ON l.converted_student_id = c.student_id
            WHERE c.teacher_id = %s
              AND {trial_filter}
              AND c.meeting_start BETWEEN %s AND %s
              AND l.funnel_stage = 'converted'
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id, start_date, end_date))
        result = cur.fetchone()
        conversions = result[0] if result else 0
        cur.close()

        conversion_rate = (
            (conversions / total_trials * 100) if total_trials > 0 else 0.0
        )

        return {
            "total_trials": total_trials,
            "conversions": conversions,
            "conversion_rate": round(conversion_rate, 2),
        }

    # ==================== Private Helper Methods ====================

    def _get_teacher_with_availability(self, teacher_id: int) -> Optional[Dict]:
        """Get teacher with availability data using PostgreSQL day_of_week structure"""
        # Get teacher info from clean schema
        query = """
            SELECT t.teacher_id, t.full_name, t.timezone
            FROM clean.teachers t
            WHERE t.teacher_id = %s
              AND t.status = 'active'
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id,))
        result = cur.fetchone()
        cur.close()

        if not result:
            return None

        # Get teacher availability from clean.teacher_availability table
        # PostgreSQL schema uses day_of_week (0-6), start_time, end_time structure
        query = """
            SELECT day_of_week, start_time, end_time
            FROM clean.teacher_availability
            WHERE teacher_id = %s
              AND is_active = true
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id,))
        availability_rows = cur.fetchall()
        cur.close()

        # Convert day_of_week structure to JSON-like format for compatibility.
        # FIX #4: canonical convention is 0=Sunday (matches clean.teacher_availability & matching_engine.py)
        # Do NOT change this mapping — both files must stay in sync.
        day_map = {0: "sun", 1: "mon", 2: "tue", 3: "wed", 4: "thu", 5: "fri", 6: "sat"}
        availability = {}

        for row in availability_rows:
            day_of_week, start_time, end_time = row
            day_key = day_map.get(day_of_week, "")

            if not day_key:
                continue

            # Generate time slots for this day based on start_time and end_time
            # Convert time values to hour/minute for calculation.
            # PostgreSQL TIME values are returned as HH:MM:SS, so only use the first 2 parts.
            if start_time:
                start_parts = str(start_time).split(":")
                start_hour, start_min = int(start_parts[0]), int(start_parts[1])
            else:
                start_hour, start_min = 9, 0
            if end_time:
                end_parts = str(end_time).split(":")
                end_hour, end_min = int(end_parts[0]), int(end_parts[1])
            else:
                end_hour, end_min = 21, 0

            # Generate 30-minute slots from start to end (matches Node.js backend) (FIX #2)
            current = start_hour * 60 + start_min
            end_time_min = end_hour * 60 + end_min

            day_slots = {}
            while current < end_time_min:
                slot_hour = current // 60
                slot_min = current % 60
                time_key = f"{slot_hour:02d}:{slot_min:02d}"
                day_slots[time_key] = True
                current += 30  # 30-minute slots

            availability[day_key] = day_slots

        return {
            "id": result[0],
            "name": result[1],
            "timezone": result[2],
            "availability": availability,
        }

    def _get_teacher(self, teacher_id: int) -> Optional[Dict]:
        """Get basic teacher info"""
        query = """
            SELECT teacher_id, full_name, timezone
            FROM clean.teachers
            WHERE teacher_id = %s
              AND status = 'active'
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id,))
        result = cur.fetchone()
        cur.close()

        if not result:
            return None

        return {"id": result[0], "name": result[1], "timezone": result[2]}

    def _get_existing_classes(
        self, teacher_id: int, start: datetime, end: datetime
    ) -> List[Dict]:
        """Get existing classes for a date range using clean schema"""
        query = """
            SELECT c.class_id, c.meeting_start, c.meeting_end, s.full_name as student_name
            FROM clean.classes c
            LEFT JOIN clean.students s ON c.student_id = s.student_id
            WHERE c.teacher_id = %s
              AND c.meeting_start < %s
              AND COALESCE(c.meeting_end, c.meeting_start + INTERVAL '30 minutes') > %s
              AND c.lifecycle_status NOT IN ('cancelled', 'no_show')
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id, end, start))
        results = cur.fetchall()
        cur.close()

        return [
            {
                "id": r[0],
                "meeting_start": r[1],
                "meeting_end": r[2],
                "student_name": r[3],
            }
            for r in results
        ]

    def _get_teacher_holidays(
        self,
        teacher_id: int,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> List[Dict]:
        """Get holidays for a teacher using clean schema."""
        if start and end:
            query = """
                SELECT holiday_date, full_day, start_time, end_time
                FROM clean.teacher_holidays
                WHERE teacher_id = %s
                  AND holiday_date BETWEEN %s::date AND %s::date
            """
            cur = self.conn.cursor()
            cur.execute(query, (teacher_id, start, end))
        else:
            query = """
                SELECT holiday_date, full_day, start_time, end_time
                FROM clean.teacher_holidays
                WHERE teacher_id = %s
            """
            cur = self.conn.cursor()
            cur.execute(query, (teacher_id,))

        results = cur.fetchall()
        cur.close()

        return [
            {
                "holiday_date": r[0],
                "full_day": r[1],
                "start_time": r[2],
                "end_time": r[3],
            }
            for r in results
        ]

    def _check_holiday_conflict(
        self, slot_start: datetime, slot_end: datetime, holidays: List[Dict]
    ) -> bool:
        """Check if slot conflicts with any holiday"""

        def _is_truthy(v: Any) -> bool:
            if isinstance(v, bool):
                return v
            if v is None:
                return False
            return str(v).strip().lower() in {"true", "t", "1", "yes", "y"}

        for holiday in holidays:
            holiday_date = holiday["holiday_date"]

            if isinstance(holiday_date, str):
                holiday_date = datetime.strptime(holiday_date, "%Y-%m-%d").date()
            else:
                holiday_date = (
                    holiday_date
                    if hasattr(holiday_date, "year")
                    and not isinstance(holiday_date, datetime)
                    else holiday_date.date()
                )

            full_day = _is_truthy(holiday.get("full_day"))
            start_t = holiday.get("start_time")
            end_t = holiday.get("end_time")

            # Full-day holiday blocks the entire calendar date.
            if full_day or not start_t or not end_t:
                holiday_start = datetime.combine(
                    holiday_date, datetime.min.time()
                ).replace(tzinfo=pytz.UTC)
                holiday_end = holiday_start + timedelta(days=1)
            else:
                # psycopg2 usually returns datetime.time; CSV may pass strings.
                if hasattr(start_t, "strftime"):
                    start_s = start_t.strftime("%H:%M")
                else:
                    start_s = str(start_t).strip()[:5]
                if hasattr(end_t, "strftime"):
                    end_s = end_t.strftime("%H:%M")
                else:
                    end_s = str(end_t).strip()[:5]

                try:
                    hh_s, mm_s = map(int, start_s.split(":", 1))
                    hh_e, mm_e = map(int, end_s.split(":", 1))
                except Exception:
                    # Defensive fallback: if we can't parse times, treat as full day.
                    holiday_start = datetime.combine(
                        holiday_date, datetime.min.time()
                    ).replace(tzinfo=pytz.UTC)
                    holiday_end = holiday_start + timedelta(days=1)
                else:
                    holiday_start = datetime(
                        holiday_date.year,
                        holiday_date.month,
                        holiday_date.day,
                        hh_s,
                        mm_s,
                        0,
                        tzinfo=pytz.UTC,
                    )
                    holiday_end = datetime(
                        holiday_date.year,
                        holiday_date.month,
                        holiday_date.day,
                        hh_e,
                        mm_e,
                        0,
                        tzinfo=pytz.UTC,
                    )

                    # If the range is invalid, treat as full day (prevents false positives).
                    if holiday_end <= holiday_start:
                        holiday_end = holiday_start + timedelta(days=1)

            # Check if slot overlaps with holiday
            if slot_start < holiday_end and slot_end > holiday_start:
                return True

        return False

    def _check_class_conflict(
        self, slot_start: datetime, slot_end: datetime, existing_classes: List[Dict]
    ) -> Optional[Dict]:
        """Check if slot conflicts with any existing class"""
        for cls in existing_classes:
            class_start = cls["meeting_start"]
            class_end = cls["meeting_end"]

            # Check for overlap using BETWEEN logic
            if slot_start < class_end and slot_end > class_start:
                return cls

        return None

    def _check_class_conflict_db(
        self, teacher_id: int, slot_start: datetime, slot_end: datetime
    ) -> Optional[Dict]:
        """Check for class conflicts using database query"""
        query = """
            SELECT c.class_id, c.meeting_start, c.meeting_end, s.full_name as student_name
            FROM clean.classes c
            LEFT JOIN clean.students s ON c.student_id = s.student_id
            WHERE c.teacher_id = %s
              AND c.meeting_start < %s
              AND COALESCE(c.meeting_end, c.meeting_start + INTERVAL '30 minutes') > %s
              AND c.lifecycle_status NOT IN ('cancelled', 'no_show')
            LIMIT 1
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id, slot_end, slot_start))
        result = cur.fetchone()
        cur.close()

        if not result:
            return None

        return {
            "id": result[0],
            "meeting_start": result[1],
            "meeting_end": result[2],
            "student_name": result[3],
        }

    def _normalize_day_key(self, day: str) -> Optional[str]:
        """Normalize day to canonical 3-letter key used by availability ('sun'..'sat')."""
        if not day:
            return None
        d = str(day).strip().lower()
        aliases = {
            "sun": "sun",
            "sunday": "sun",
            "mon": "mon",
            "monday": "mon",
            "tue": "tue",
            "tues": "tue",
            "tuesday": "tue",
            "wed": "wed",
            "weds": "wed",
            "wednesday": "wed",
            "thu": "thu",
            "thur": "thu",
            "thurs": "thu",
            "thursday": "thu",
            "fri": "fri",
            "friday": "fri",
            "sat": "sat",
            "saturday": "sat",
        }
        if d in aliases:
            return aliases[d]
        if len(d) >= 3 and d[:3] in aliases:
            return aliases[d[:3]]
        return None

    def _get_next_occurrences(
        self, day_key: str, time: str, weeks: int
    ) -> List[datetime]:
        """Calculate next N UTC occurrences of a canonical day_key ('sun'..'sat') and time."""
        hour, minute = map(int, time.split(":"))
        today = datetime.now(pytz.UTC)

        # Python weekday(): 0=Mon..6=Sun → map our canonical keys to python weekday index
        python_weekday_map = {
            "mon": 0,
            "tue": 1,
            "wed": 2,
            "thu": 3,
            "fri": 4,
            "sat": 5,
            "sun": 6,
        }
        target_weekday = python_weekday_map.get(day_key)
        if target_weekday is None:
            return []

        days_ahead = target_weekday - today.weekday()
        if days_ahead <= 0:
            days_ahead += 7

        next_date = (today + timedelta(days=days_ahead)).replace(
            hour=hour, minute=minute, second=0, microsecond=0
        )
        return [next_date + timedelta(weeks=i) for i in range(weeks)]

    def _calculate_total_slots(self, availability: Dict) -> int:
        """Calculate total available slots from teacher availability"""
        total_slots = 0
        days_of_week = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

        for day in days_of_week:
            day_schedule = availability.get(day, {})
            if day_schedule:
                for time_slot, is_available in day_schedule.items():
                    if is_available:
                        total_slots += 1

        return total_slots

    def _parse_json(self, json_str: str) -> Dict:
        """Safely parse JSON string"""
        import json

        try:
            return json.loads(json_str) if json_str else {}
        except (json.JSONDecodeError, TypeError):
            return {}

    def _calculate_booked_slots(self, teacher_id: int) -> int:
        """
        Calculate booked slots by looking at actual scheduled classes for the upcoming 7 days.
        Uses the unified clean.classes table.
        """
        query = """
            SELECT
                meeting_start,
                COALESCE(meeting_end, meeting_start + INTERVAL '30 minutes') AS meeting_end
            FROM clean.classes
            WHERE teacher_id = %s
              AND meeting_start BETWEEN NOW() AND NOW() + INTERVAL '7 days'
              AND lifecycle_status IN ('confirmed', 'in_progress')
        """

        cur = self.conn.cursor()
        cur.execute(query, (teacher_id,))
        results = cur.fetchall()
        cur.close()

        booked_slots = 0
        for row in results:
            start_time = row[0]
            end_time = row[1]
            duration_minutes = (end_time - start_time).total_seconds() / 60.0
            slots_to_span = int((duration_minutes + 29) // 30)
            booked_slots += max(1, slots_to_span)

        return booked_slots
