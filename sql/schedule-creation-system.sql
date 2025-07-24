-- =============================================================================
-- SCHEDULE CREATION SYSTEM - Inspired by OpenGamma Strata PeriodicSchedule
-- =============================================================================
-- This system implements schedule generation for equity swaps based on
-- OpenGamma Strata's PeriodicSchedule API with PostgreSQL functions
-- =============================================================================

-- =============================================================================
-- ENUMERATIONS AND REFERENCE DATA
-- =============================================================================

-- Business Day Convention types (aligned with Strata)
CREATE TYPE business_day_convention AS ENUM (
    'NO_ADJUST',           -- No adjustment
    'FOLLOWING',           -- Following business day
    'MODIFIED_FOLLOWING',  -- Modified following business day
    'PRECEDING',           -- Preceding business day
    'MODIFIED_PRECEDING'   -- Modified preceding business day
);

-- Frequency types for schedule generation
CREATE TYPE schedule_frequency AS ENUM (
    'DAILY',
    'WEEKLY',
    'MONTHLY',
    'QUARTERLY',
    'SEMI_ANNUAL',
    'ANNUAL',
    'TERMINAL'
);

-- Stub convention types
CREATE TYPE stub_convention AS ENUM (
    'NONE',
    'SHORT_INITIAL',
    'LONG_INITIAL',
    'SHORT_FINAL',
    'LONG_FINAL',
    'SMART_INITIAL',
    'SMART_FINAL',
    'BOTH'
);

-- Roll convention types
CREATE TYPE roll_convention AS ENUM (
    'EOM',      -- End of month
    'IMM',      -- IMM dates (3rd Wednesday)
    'IMM_ISO',  -- IMM ISO dates
    'DAY_1',    -- 1st of month
    'DAY_15',   -- 15th of month
    'DAY_30'    -- 30th of month
);

-- =============================================================================
-- SCHEDULE DEFINITION TABLES
-- =============================================================================

-- Schedule Definition - Core schedule configuration
CREATE TABLE IF NOT EXISTS ScheduleDefinition (
    schedule_id VARCHAR(50) PRIMARY KEY,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_type VARCHAR(30) NOT NULL CHECK (schedule_type IN (
        'PAYMENT', 'RESET', 'OBSERVATION', 'EXERCISE', 'SETTLEMENT')),
    
    -- Core schedule parameters
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    frequency schedule_frequency NOT NULL,
    business_day_convention business_day_convention NOT NULL DEFAULT 'MODIFIED_FOLLOWING',
    
    -- Optional parameters
    first_regular_start_date DATE,
    last_regular_end_date DATE,
    start_stub_convention stub_convention DEFAULT 'NONE',
    end_stub_convention stub_convention DEFAULT 'NONE',
    roll_convention roll_convention DEFAULT 'EOM',
    
    -- Business centers (JSON array of business center codes)
    business_centers JSONB DEFAULT '["USNY", "GBLO", "EUTA"]',
    
    -- Override flags
    override_start_date DATE,
    override_end_date DATE,
    
    -- Metadata
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ck_schedule_dates CHECK (end_date > start_date),
    CONSTRAINT ck_regular_dates CHECK (
        first_regular_start_date IS NULL OR 
        last_regular_end_date IS NULL OR 
        last_regular_end_date > first_regular_start_date
    )
);

-- Schedule Period - Individual periods within a schedule
CREATE TABLE IF NOT EXISTS SchedulePeriod (
    period_id VARCHAR(50) PRIMARY KEY,
    schedule_id VARCHAR(50) NOT NULL,
    
    -- Period boundaries
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    adjusted_start_date DATE NOT NULL,
    adjusted_end_date DATE NOT NULL,
    
    -- Period type
    period_type VARCHAR(20) NOT NULL CHECK (period_type IN (
        'REGULAR', 'INITIAL_STUB', 'FINAL_STUB', 'OVERRIDE')),
    
    -- Period sequence
    period_number INTEGER NOT NULL,
    total_periods INTEGER NOT NULL,
    
    -- Additional metadata
    is_stub BOOLEAN DEFAULT FALSE,
    days_in_period INTEGER NOT NULL,
    
    CONSTRAINT fk_schedule_period 
        FOREIGN KEY (schedule_id) REFERENCES ScheduleDefinition(schedule_id) ON DELETE CASCADE,
    CONSTRAINT ck_period_dates CHECK (end_date > start_date),
    CONSTRAINT ck_adjusted_dates CHECK (adjusted_end_date >= adjusted_start_date)
);

-- Schedule Event - Individual events within periods
CREATE TABLE IF NOT EXISTS ScheduleEvent (
    event_id VARCHAR(50) PRIMARY KEY,
    period_id VARCHAR(50) NOT NULL,
    schedule_id VARCHAR(50) NOT NULL,
    
    -- Event details
    event_date DATE NOT NULL,
    adjusted_event_date DATE NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    event_subtype VARCHAR(50),
    
    -- Event sequence
    event_number INTEGER NOT NULL,
    total_events INTEGER NOT NULL,
    
    -- Event status
    status VARCHAR(20) DEFAULT 'SCHEDULED' CHECK (status IN (
        'SCHEDULED', 'COMPLETED', 'CANCELLED', 'ADJUSTED')),
    
    -- Optional references
    reference_amount DECIMAL(18,6),
    reference_rate DECIMAL(10,6),
    
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_schedule_event_period 
        FOREIGN KEY (period_id) REFERENCES SchedulePeriod(period_id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_event_schedule 
        FOREIGN KEY (schedule_id) REFERENCES ScheduleDefinition(schedule_id) ON DELETE CASCADE
);

-- =============================================================================
-- BUSINESS CALENDAR SUPPORT
-- =============================================================================

-- Business Calendar - Holiday and business day tracking
CREATE TABLE IF NOT EXISTS BusinessCalendar (
    calendar_id VARCHAR(50) PRIMARY KEY,
    calendar_name VARCHAR(100) NOT NULL,
    business_center_code VARCHAR(10) NOT NULL UNIQUE,
    country_code CHAR(2),
    
    -- Holiday data (JSON array of holiday dates)
    holidays JSONB DEFAULT '[]',
    
    -- Weekend definition
    weekend_days JSONB DEFAULT '[6, 7]', -- Saturday=6, Sunday=7
    
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Holiday Dates - Individual holiday records
CREATE TABLE IF NOT EXISTS HolidayDate (
    holiday_id VARCHAR(50) PRIMARY KEY,
    calendar_id VARCHAR(50) NOT NULL,
    holiday_date DATE NOT NULL,
    holiday_name VARCHAR(200),
    holiday_type VARCHAR(50),
    
    CONSTRAINT fk_holiday_calendar 
        FOREIGN KEY (calendar_id) REFERENCES BusinessCalendar(calendar_id) ON DELETE CASCADE,
    CONSTRAINT uk_holiday_date UNIQUE (calendar_id, holiday_date)
);

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Function to check if a date is a business day
CREATE OR REPLACE FUNCTION is_business_day(
    p_date DATE,
    p_calendar_id VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    v_weekend_days JSONB;
    v_holidays JSONB;
    v_day_of_week INTEGER;
BEGIN
    -- Get calendar data
    SELECT weekend_days, holidays 
    INTO v_weekend_days, v_holidays
    FROM BusinessCalendar 
    WHERE calendar_id = p_calendar_id;
    
    IF v_weekend_days IS NULL THEN
        RETURN TRUE;
    END IF;
    
    -- Check if weekend
    v_day_of_week := EXTRACT(DOW FROM p_date);
    IF v_day_of_week = ANY(SELECT jsonb_array_elements_text(v_weekend_days)::INTEGER[]) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if holiday
    IF p_date::TEXT = ANY(SELECT jsonb_array_elements_text(v_holidays)) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to adjust date according to business day convention
CREATE OR REPLACE FUNCTION adjust_business_day(
    p_date DATE,
    p_convention business_day_convention,
    p_calendar_id VARCHAR(50)
) RETURNS DATE AS $$
DECLARE
    v_adjusted_date DATE := p_date;
    v_day_increment INTEGER := 1;
BEGIN
    -- Handle NO_ADJUST convention
    IF p_convention = 'NO_ADJUST' THEN
        RETURN p_date;
    END IF;
    
    -- Loop until we find a business day
    WHILE NOT is_business_day(v_adjusted_date, p_calendar_id) LOOP
        CASE p_convention
            WHEN 'FOLLOWING' THEN
                v_adjusted_date := v_adjusted_date + INTERVAL '1 day';
            WHEN 'MODIFIED_FOLLOWING' THEN
                v_adjusted_date := v_adjusted_date + INTERVAL '1 day';
                -- Check if we crossed into next month
                IF EXTRACT(MONTH FROM v_adjusted_date) != EXTRACT(MONTH FROM p_date) THEN
                    v_adjusted_date := p_date - INTERVAL '1 day';
                    WHILE NOT is_business_day(v_adjusted_date, p_calendar_id) LOOP
                        v_adjusted_date := v_adjusted_date - INTERVAL '1 day';
                    END LOOP;
                    EXIT;
                END IF;
            WHEN 'PRECEDING' THEN
                v_adjusted_date := v_adjusted_date - INTERVAL '1 day';
            WHEN 'MODIFIED_PRECEDING' THEN
                v_adjusted_date := v_adjusted_date - INTERVAL '1 day';
                -- Check if we crossed into previous month
                IF EXTRACT(MONTH FROM v_adjusted_date) != EXTRACT(MONTH FROM p_date) THEN
                    v_adjusted_date := p_date + INTERVAL '1 day';
                    WHILE NOT is_business_day(v_adjusted_date, p_calendar_id) LOOP
                        v_adjusted_date := v_adjusted_date + INTERVAL '1 day';
                    END LOOP;
                    EXIT;
                END IF;
        END CASE;
    END LOOP;
    
    RETURN v_adjusted_date;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SCHEDULE GENERATION FUNCTIONS
-- =============================================================================

-- Main schedule generation function inspired by Strata PeriodicSchedule
CREATE OR REPLACE FUNCTION generate_schedule(
    p_schedule_id VARCHAR(50),
    p_start_date DATE,
    p_end_date DATE,
    p_frequency schedule_frequency,
    p_business_day_convention business_day_convention DEFAULT 'MODIFIED_FOLLOWING',
    p_calendar_id VARCHAR(50) DEFAULT 'USNY',
    p_first_regular_start_date DATE DEFAULT NULL,
    p_last_regular_end_date DATE DEFAULT NULL,
    p_start_stub_convention stub_convention DEFAULT 'NONE',
    p_end_stub_convention stub_convention DEFAULT 'NONE',
    p_roll_convention roll_convention DEFAULT 'EOM'
) RETURNS TABLE (
    period_number INTEGER,
    start_date DATE,
    end_date DATE,
    adjusted_start_date DATE,
    adjusted_end_date DATE,
    period_type VARCHAR(20),
    days_in_period INTEGER
) AS $$
DECLARE
    v_period_start DATE;
    v_period_end DATE;
    v_period_number INTEGER := 1;
    v_total_periods INTEGER;
    v_current_date DATE := p_start_date;
    v_next_date DATE;
    v_months_increment INTEGER;
    v_period_id VARCHAR(50);
BEGIN
    -- Calculate months increment based on frequency
    CASE p_frequency
        WHEN 'DAILY' THEN v_months_increment := 0;
        WHEN 'WEEKLY' THEN v_months_increment := 0;
        WHEN 'MONTHLY' THEN v_months_increment := 1;
        WHEN 'QUARTERLY' THEN v_months_increment := 3;
        WHEN 'SEMI_ANNUAL' THEN v_months_increment := 6;
        WHEN 'ANNUAL' THEN v_months_increment := 12;
        WHEN 'TERMINAL' THEN v_months_increment := 0;
        ELSE v_months_increment := 1;
    END CASE;
    
    -- Estimate total periods for numbering
    v_total_periods := CEIL((p_end_date - p_start_date) / 30.0);
    
    -- Handle terminal frequency (single period)
    IF p_frequency = 'TERMINAL' THEN
        RETURN QUERY
        SELECT 
            1,
            p_start_date,
            p_end_date,
            adjust_business_day(p_start_date, p_business_day_convention, p_calendar_id),
            adjust_business_day(p_end_date, p_business_day_convention, p_calendar_id),
            'REGULAR',
            p_end_date - p_start_date;
        RETURN;
    END IF;
    
    -- Generate periods based on frequency
    WHILE v_current_date < p_end_date LOOP
        -- Calculate next period end
        IF v_months_increment > 0 THEN
            v_next_date := (v_current_date + INTERVAL '1 month' * v_months_increment);
            -- Adjust based on roll convention
            CASE p_roll_convention
                WHEN 'EOM' THEN
                    v_next_date := (DATE_TRUNC('month', v_next_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
                WHEN 'DAY_1' THEN
                    v_next_date := DATE_TRUNC('month', v_next_date)::DATE;
                WHEN 'DAY_15' THEN
                    v_next_date := (DATE_TRUNC('month', v_next_date) + INTERVAL '14 days')::DATE;
                WHEN 'DAY_30' THEN
                    v_next_date := (DATE_TRUNC('month', v_next_date) + INTERVAL '29 days')::DATE;
                ELSE
                    -- Default to end of period
                    v_next_date := LEAST(v_next_date, p_end_date);
            END CASE;
        ELSE
            -- Daily/weekly frequency
            IF p_frequency = 'WEEKLY' THEN
                v_next_date := v_current_date + INTERVAL '7 days';
            ELSE
                v_next_date := v_current_date + INTERVAL '1 day';
            END IF;
        END IF;
        
        -- Ensure we don't exceed end date
        v_next_date := LEAST(v_next_date, p_end_date);
        
        -- Determine period type
        DECLARE
            v_period_type VARCHAR(20) := 'REGULAR';
        BEGIN
            -- Check for stub periods
            IF v_period_number = 1 AND v_current_date != p_first_regular_start_date THEN
                v_period_type := 'INITIAL_STUB';
            ELSIF v_next_date = p_end_date AND v_next_date != p_last_regular_end_date THEN
                v_period_type := 'FINAL_STUB';
            END IF;
            
            -- Return the period
            RETURN QUERY
            SELECT 
                v_period_number,
                v_current_date,
                v_next_date,
                adjust_business_day(v_current_date, p_business_day_convention, p_calendar_id),
                adjust_business_day(v_next_date, p_business_day_convention, p_calendar_id),
                v_period_type,
                v_next_date - v_current_date;
        END;
        
        -- Move to next period
        v_current_date := v_next_date;
        v_period_number := v_period_number + 1;
        
        -- Exit if we've reached the end
        EXIT WHEN v_current_date >= p_end_date;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SCHEDULE EVENT GENERATION
-- =============================================================================

-- Function to generate events within schedule periods
CREATE OR REPLACE FUNCTION generate_schedule_events(
    p_schedule_id VARCHAR(50),
    p_event_type VARCHAR(30),
    p_event_subtype VARCHAR(50) DEFAULT NULL,
    p_events_per_period INTEGER DEFAULT 1
) RETURNS TABLE (
    event_number INTEGER,
    event_date DATE,
    adjusted_event_date DATE,
    event_type VARCHAR(30),
    event_subtype VARCHAR(50),
    period_number INTEGER
) AS $$
DECLARE
    v_period RECORD;
    v_event_number INTEGER := 1;
    v_event_date DATE;
    v_calendar_id VARCHAR(50);
    v_business_day_convention business_day_convention;
BEGIN
    -- Get schedule details
    SELECT business_day_convention, business_centers->>0
    INTO v_business_day_convention, v_calendar_id
    FROM ScheduleDefinition
    WHERE schedule_id = p_schedule_id;
    
    -- Loop through all periods
    FOR v_period IN
        SELECT * FROM SchedulePeriod WHERE schedule_id = p_schedule_id ORDER BY period_number
    LOOP
        -- Generate events within each period
        FOR i IN 1..p_events_per_period LOOP
            -- Calculate event date (end of period for payment events, start for others)
            IF p_event_type IN ('PAYMENT', 'RESET') THEN
                v_event_date := v_period.adjusted_end_date;
            ELSE
                v_event_date := v_period.adjusted_start_date;
            END IF;
            
            -- Adjust for business days
            v_event_date := adjust_business_day(v_event_date, v_business_day_convention, v_calendar_id);
            
            RETURN QUERY
            SELECT 
                v_event_number,
                v_event_date,
                v_event_date, -- Adjusted date (already adjusted)
                p_event_type,
                p_event_subtype,
                v_period.period_number;
            
            v_event_number := v_event_number + 1;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMPLETE SCHEDULE CREATION PROCEDURE
-- =============================================================================

-- Master procedure to create complete schedule with periods and events
CREATE OR REPLACE FUNCTION create_complete_schedule(
    p_schedule_name VARCHAR(200),
    p_schedule_type VARCHAR(30),
    p_start_date DATE,
    p_end_date DATE,
    p_frequency schedule_frequency,
    p_business_day_convention business_day_convention DEFAULT 'MODIFIED_FOLLOWING',
    p_calendar_id VARCHAR(50) DEFAULT 'USNY',
    p_event_type VARCHAR(30) DEFAULT 'PAYMENT',
    p_events_per_period INTEGER DEFAULT 1
) RETURNS VARCHAR(50) AS $$
DECLARE
    v_schedule_id VARCHAR(50);
    v_period RECORD;
    v_event RECORD;
    v_period_id VARCHAR(50);
    v_event_id VARCHAR(50);
BEGIN
    -- Generate schedule ID
    v_schedule_id := 'SCH_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '_' || 
                     LEFT(MD5(RANDOM()::TEXT), 8);
    
    -- Create schedule definition
    INSERT INTO ScheduleDefinition (
        schedule_id, schedule_name, schedule_type, 
        start_date, end_date, frequency, business_day_convention,
        business_centers
    ) VALUES (
        v_schedule_id, p_schedule_name, p_schedule_type,
        p_start_date, p_end_date, p_frequency, p_business_day_convention,
        JSONB_BUILD_ARRAY(p_calendar_id)
    );
    
    -- Generate and store periods
    FOR v_period IN
        SELECT * FROM generate_schedule(
            v_schedule_id, p_start_date, p_end_date, p_frequency,
            p_business_day_convention, p_calendar_id
        )
    LOOP
        v_period_id := v_schedule_id || '_P' || LPAD(v_period.period_number::TEXT, 3, '0');
        
        INSERT INTO SchedulePeriod (
            period_id, schedule_id, start_date, end_date,
            adjusted_start_date, adjusted_end_date, period_type,
            period_number, total_periods, days_in_period
        ) VALUES (
            v_period_id, v_schedule_id, v_period.start_date, v_period.end_date,
            v_period.adjusted_start_date, v_period.adjusted_end_date, v_period.period_type,
            v_period.period_number, v_period.period_number, v_period.days_in_period
        );
    END LOOP;
    
    -- Generate and store events
    FOR v_event IN
        SELECT * FROM generate_schedule_events(
            v_schedule_id, p_event_type, NULL, p_events_per_period
        )
    LOOP
        v_event_id := v_schedule_id || '_E' || LPAD(v_event.event_number::TEXT, 4, '0');
        
        INSERT INTO ScheduleEvent (
            event_id, period_id, schedule_id, event_date,
            adjusted_event_date, event_type, event_number, total_events
        ) VALUES (
            v_event_id, 
            v_schedule_id || '_P' || LPAD(v_event.period_number::TEXT, 3, '0'),
            v_schedule_id, v_event.event_date, v_event.adjusted_event_date,
            v_event.event_type, v_event.event_number, v_event.period_number
        );
    END LOOP;
    
    RETURN v_schedule_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- BUSINESS CALENDAR SETUP
-- =============================================================================

-- Insert standard business calendars
INSERT INTO BusinessCalendar (calendar_id, calendar_name, business_center_code, country_code, weekend_days) VALUES
('USNY', 'New York', 'USNY', 'US', '[1, 7]'), -- Sunday=1, Saturday=7
('GBLO', 'London', 'GBLO', 'GB', '[1, 7]'),
('EUTA', 'TARGET', 'EUTA', 'EU', '[1, 7]'),
('JPTO', 'Tokyo', 'JPTO', 'JP', '[1, 7]'),
('AUSY', 'Sydney', 'AUSY', 'AU', '[1, 7]');

-- Insert sample holidays (US New York)
INSERT INTO HolidayDate (holiday_id, calendar_id, holiday_date, holiday_name, holiday_type) VALUES
('HOL001', 'USNY', '2024-01-01', 'New Year''s Day', 'PUBLIC'),
('HOL002', 'USNY', '2024-01-15', 'Martin Luther King Jr. Day', 'PUBLIC'),
('HOL003', 'USNY', '2024-02-19', 'Presidents Day', 'PUBLIC'),
('HOL004', 'USNY', '2024-05-27', 'Memorial Day', 'PUBLIC'),
('HOL005', 'USNY', '2024-07-04', 'Independence Day', 'PUBLIC'),
('HOL006', 'USNY', '2024-09-02', 'Labor Day', 'PUBLIC'),
('HOL007', 'USNY', '2024-11-28', 'Thanksgiving Day', 'PUBLIC'),
('HOL008', 'USNY', '2024-11-29', 'Thanksgiving Friday', 'PUBLIC'),
('HOL008', 'USNY', '2024-12-25', 'Christmas Day', 'PUBLIC');

-- =============================================================================
-- UTILITY VIEWS
-- =============================================================================

-- Complete schedule view
CREATE OR REPLACE VIEW schedule_overview AS
SELECT 
    sd.schedule_id,
    sd.schedule_name,
    sd.schedule_type,
    sd.start_date,
    sd.end_date,
    sd.frequency,
    sd.business_day_convention,
    COUNT(DISTINCT sp.period_id) AS total_periods,
    COUNT(DISTINCT se.event_id) AS total_events,
    MIN(sp.adjusted_start_date) AS first_period_start,
    MAX(sp.adjusted_end_date) AS last_period_end
FROM ScheduleDefinition sd
LEFT JOIN SchedulePeriod sp ON sd.schedule_id = sp.schedule_id
LEFT JOIN ScheduleEvent se ON sd.schedule_id = se.schedule_id
GROUP BY sd.schedule_id, sd.schedule_name, sd.schedule_type, sd.start_date, 
         sd.end_date, sd.frequency, sd.business_day_convention;

-- Schedule details with periods and events
CREATE OR REPLACE VIEW schedule_details AS
SELECT 
    sd.schedule_id,
    sd.schedule_name,
    sp.period_number,
    sp.start_date,
    sp.end_date,
    sp.adjusted_start_date,
    sp.adjusted_end_date,
    sp.period_type,
    sp.days_in_period,
    se.event_number,
    se.event_date,
    se.adjusted_event_date,
    se.event_type,
    se.status
FROM ScheduleDefinition sd
JOIN SchedulePeriod sp ON sd.schedule_id = sp.schedule_id
LEFT JOIN ScheduleEvent se ON sp.period_id = se.period_id
ORDER BY sd.schedule_id, sp.period_number, se.event_number;

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Function to validate schedule consistency
CREATE OR REPLACE FUNCTION validate_schedule(p_schedule_id VARCHAR(50))
RETURNS TABLE (
    validation_type VARCHAR(50),
    validation_message TEXT,
    is_valid BOOLEAN
) AS $$
BEGIN
    -- Check for overlapping periods
    RETURN QUERY
    SELECT 
        'OVERLAPPING_PERIODS'::VARCHAR,
        'Periods should not overlap'::TEXT,
        NOT EXISTS (
            SELECT 1 
            FROM SchedulePeriod sp1
            JOIN SchedulePeriod sp2 ON sp1.schedule_id = sp2.schedule_id
            WHERE sp1.schedule_id = p_schedule_id
              AND sp1.period_id != sp2.period_id
              AND sp1.adjusted_start_date <= sp2.adjusted_end_date
              AND sp2.adjusted_start_date <= sp1.adjusted_end_date
        );
    
    -- Check for gaps in schedule
    RETURN QUERY
    SELECT 
        'GAPS_IN_SCHEDULE'::VARCHAR,
        'Schedule should have no gaps'::TEXT,
        NOT EXISTS (
            SELECT 1
            FROM SchedulePeriod sp1
            JOIN SchedulePeriod sp2 ON sp1.schedule_id = sp2.schedule_id
            WHERE sp1.schedule_id = p_schedule_id
              AND sp1.period_number = sp2.period_number - 1
              AND sp1.adjusted_end_date != sp2.adjusted_start_date
        );
    
    -- Check for proper date ordering
    RETURN QUERY
    SELECT 
        'DATE_ORDERING'::VARCHAR,
        'Start dates should be before end dates'::TEXT,
        NOT EXISTS (
            SELECT 1
            FROM SchedulePeriod
            WHERE schedule_id = p_schedule_id
              AND adjusted_start_date >= adjusted_end_date
        );
END;
$$ LANGUAGE plpgsql;

SELECT 'Schedule Creation System Created Successfully' AS status;
