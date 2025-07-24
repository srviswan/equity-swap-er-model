-- =============================================================================
-- MS SQL SERVER COMPATIBLE SCHEDULE CREATION SYSTEM
-- =============================================================================
-- This is a Microsoft SQL Server compatible version of the schedule creation system
-- inspired by OpenGamma Strata PeriodicSchedule API
-- =============================================================================

-- =============================================================================
-- ENUMERATIONS AND REFERENCE DATA
-- =============================================================================

-- Business Day Convention types (as lookup tables instead of enums)
CREATE TABLE BusinessDayConvention (
    convention_id INT IDENTITY(1,1) PRIMARY KEY,
    convention_code VARCHAR(30) UNIQUE NOT NULL,
    convention_name VARCHAR(100) NOT NULL,
    description VARCHAR(500)
);

INSERT INTO BusinessDayConvention (convention_code, convention_name, description) VALUES
('NO_ADJUST', 'No Adjustment', 'No business day adjustment'),
('FOLLOWING', 'Following', 'Following business day'),
('MODIFIED_FOLLOWING', 'Modified Following', 'Modified following business day'),
('PRECEDING', 'Preceding', 'Preceding business day'),
('MODIFIED_PRECEDING', 'Modified Preceding', 'Modified preceding business day');

-- Schedule Frequency types
CREATE TABLE ScheduleFrequency (
    frequency_id INT IDENTITY(1,1) PRIMARY KEY,
    frequency_code VARCHAR(20) UNIQUE NOT NULL,
    frequency_name VARCHAR(50) NOT NULL,
    months_increment INT,
    days_increment INT,
    description VARCHAR(200)
);

INSERT INTO ScheduleFrequency (frequency_code, frequency_name, months_increment, days_increment, description) VALUES
('DAILY', 'Daily', NULL, 1, 'Daily frequency'),
('WEEKLY', 'Weekly', NULL, 7, 'Weekly frequency'),
('MONTHLY', 'Monthly', 1, NULL, 'Monthly frequency'),
('QUARTERLY', 'Quarterly', 3, NULL, 'Quarterly frequency'),
('SEMI_ANNUAL', 'Semi-Annual', 6, NULL, 'Semi-annual frequency'),
('ANNUAL', 'Annual', 12, NULL, 'Annual frequency'),
('TERMINAL', 'Terminal', NULL, NULL, 'Single terminal payment');

-- Stub Convention types
CREATE TABLE StubConvention (
    stub_id INT IDENTITY(1,1) PRIMARY KEY,
    stub_code VARCHAR(30) UNIQUE NOT NULL,
    stub_name VARCHAR(50) NOT NULL,
    description VARCHAR(200)
);

INSERT INTO StubConvention (stub_code, stub_name, description) VALUES
('NONE', 'None', 'No stub periods'),
('SHORT_INITIAL', 'Short Initial', 'Short initial stub period'),
('LONG_INITIAL', 'Long Initial', 'Long initial stub period'),
('SHORT_FINAL', 'Short Final', 'Short final stub period'),
('LONG_FINAL', 'Long Final', 'Long final stub period'),
('SMART_INITIAL', 'Smart Initial', 'Smart initial stub'),
('SMART_FINAL', 'Smart Final', 'Smart final stub'),
('BOTH', 'Both', 'Both initial and final stubs');

-- Roll Convention types
CREATE TABLE RollConvention (
    roll_id INT IDENTITY(1,1) PRIMARY KEY,
    roll_code VARCHAR(20) UNIQUE NOT NULL,
    roll_name VARCHAR(50) NOT NULL,
    description VARCHAR(200)
);

INSERT INTO RollConvention (roll_code, roll_name, description) VALUES
('EOM', 'End of Month', 'End of month roll'),
('IMM', 'IMM Dates', 'IMM dates (3rd Wednesday)'),
('IMM_ISO', 'IMM ISO', 'IMM ISO dates'),
('DAY_1', 'Day 1', '1st of month'),
('DAY_15', 'Day 15', '15th of month'),
('DAY_30', 'Day 30', '30th of month');

-- =============================================================================
-- SCHEDULE DEFINITION TABLES
-- =============================================================================

CREATE TABLE ScheduleDefinition (
    schedule_id VARCHAR(50) PRIMARY KEY,
    schedule_name VARCHAR(200) NOT NULL,
    schedule_type VARCHAR(30) NOT NULL CHECK (schedule_type IN (
        'PAYMENT', 'RESET', 'OBSERVATION', 'EXERCISE', 'SETTLEMENT')),
    
    -- Core schedule parameters
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    frequency_code VARCHAR(20) NOT NULL,
    convention_code VARCHAR(30) NOT NULL DEFAULT 'MODIFIED_FOLLOWING',
    
    -- Optional parameters
    first_regular_start_date DATE,
    last_regular_end_date DATE,
    stub_code VARCHAR(30) DEFAULT 'NONE',
    roll_code VARCHAR(20) DEFAULT 'EOM',
    
    -- Business centers (comma-separated list)
    business_centers VARCHAR(500) DEFAULT 'USNY',
    
    -- Override flags
    override_start_date DATE,
    override_end_date DATE,
    
    -- Metadata
    created_datetime DATETIME2 DEFAULT GETDATE(),
    updated_datetime DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT ck_schedule_dates CHECK (end_date > start_date),
    CONSTRAINT fk_schedule_frequency FOREIGN KEY (frequency_code) REFERENCES ScheduleFrequency(frequency_code),
    CONSTRAINT fk_schedule_convention FOREIGN KEY (convention_code) REFERENCES BusinessDayConvention(convention_code),
    CONSTRAINT fk_schedule_stub FOREIGN KEY (stub_code) REFERENCES StubConvention(stub_code),
    CONSTRAINT fk_schedule_roll FOREIGN KEY (roll_code) REFERENCES RollConvention(roll_code)
);

CREATE TABLE SchedulePeriod (
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
    period_number INT NOT NULL,
    total_periods INT NOT NULL,
    
    -- Additional metadata
    is_stub BIT DEFAULT 0,
    days_in_period INT NOT NULL,
    
    CONSTRAINT fk_schedule_period FOREIGN KEY (schedule_id) REFERENCES ScheduleDefinition(schedule_id) ON DELETE CASCADE,
    CONSTRAINT ck_period_dates CHECK (end_date > start_date),
    CONSTRAINT ck_adjusted_dates CHECK (adjusted_end_date >= adjusted_start_date)
);

CREATE TABLE ScheduleEvent (
    event_id VARCHAR(50) PRIMARY KEY,
    period_id VARCHAR(50) NOT NULL,
    schedule_id VARCHAR(50) NOT NULL,
    
    -- Event details
    event_date DATE NOT NULL,
    adjusted_event_date DATE NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    event_subtype VARCHAR(50),
    
    -- Event sequence
    event_number INT NOT NULL,
    total_events INT NOT NULL,
    
    -- Event status
    status VARCHAR(20) DEFAULT 'SCHEDULED' CHECK (status IN (
        'SCHEDULED', 'COMPLETED', 'CANCELLED', 'ADJUSTED')),
    
    -- Optional references
    reference_amount DECIMAL(18,6),
    reference_rate DECIMAL(10,6),
    
    created_datetime DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_schedule_event_period FOREIGN KEY (period_id) REFERENCES SchedulePeriod(period_id) ON DELETE CASCADE,
    CONSTRAINT fk_schedule_event_schedule FOREIGN KEY (schedule_id) REFERENCES ScheduleDefinition(schedule_id) ON DELETE CASCADE
);

-- =============================================================================
-- BUSINESS CALENDAR SUPPORT
-- =============================================================================

CREATE TABLE BusinessCalendar (
    calendar_id VARCHAR(50) PRIMARY KEY,
    calendar_name VARCHAR(100) NOT NULL,
    business_center_code VARCHAR(10) NOT NULL UNIQUE,
    country_code CHAR(2),
    
    -- Weekend definition (comma-separated day numbers: 1=Sunday, 7=Saturday)
    weekend_days VARCHAR(20) DEFAULT '1,7',
    
    created_datetime DATETIME2 DEFAULT GETDATE(),
    updated_datetime DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE HolidayDate (
    holiday_id VARCHAR(50) PRIMARY KEY,
    calendar_id VARCHAR(50) NOT NULL,
    holiday_date DATE NOT NULL,
    holiday_name VARCHAR(200),
    holiday_type VARCHAR(50),
    
    CONSTRAINT fk_holiday_calendar FOREIGN KEY (calendar_id) REFERENCES BusinessCalendar(calendar_id) ON DELETE CASCADE,
    CONSTRAINT uk_holiday_date UNIQUE (calendar_id, holiday_date)
);

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Function to check if a date is a business day
CREATE OR ALTER FUNCTION dbo.IsBusinessDay(
    @p_date DATE,
    @p_calendar_id VARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @is_business BIT = 1;
    DECLARE @weekend_days VARCHAR(20);
    DECLARE @day_of_week INT;
    
    -- Get calendar data
    SELECT @weekend_days = weekend_days
    FROM BusinessCalendar
    WHERE calendar_id = @p_calendar_id;
    
    IF @weekend_days IS NULL
        RETURN 1;
    
    -- Check if weekend
    SET @day_of_week = DATEPART(WEEKDAY, @p_date);
    
    -- SQL Server: 1=Sunday, 7=Saturday (depends on DATEFIRST setting)
    IF CHARINDEX(CAST(@day_of_week AS VARCHAR), @weekend_days) > 0
        SET @is_business = 0;
    
    -- Check if holiday
    IF EXISTS (SELECT 1 FROM HolidayDate WHERE calendar_id = @p_calendar_id AND holiday_date = @p_date)
        SET @is_business = 0;
    
    RETURN @is_business;
END;
GO

-- Function to adjust date according to business day convention
CREATE OR ALTER FUNCTION dbo.AdjustBusinessDay(
    @p_date DATE,
    @p_convention VARCHAR(30),
    @p_calendar_id VARCHAR(50)
)
RETURNS DATE
AS
BEGIN
    DECLARE @adjusted_date DATE = @p_date;
    DECLARE @original_month INT = MONTH(@p_date);
    
    -- Handle NO_ADJUST convention
    IF @p_convention = 'NO_ADJUST'
        RETURN @p_date;
    
    -- Loop until we find a business day
    WHILE dbo.IsBusinessDay(@adjusted_date, @p_calendar_id) = 0
    BEGIN
        IF @p_convention = 'FOLLOWING'
            SET @adjusted_date = DATEADD(DAY, 1, @adjusted_date);
        ELSE IF @p_convention = 'MODIFIED_FOLLOWING'
        BEGIN
            SET @adjusted_date = DATEADD(DAY, 1, @adjusted_date);
            -- Check if we crossed into next month
            IF MONTH(@adjusted_date) != @original_month
            BEGIN
                SET @adjusted_date = @p_date;
                WHILE dbo.IsBusinessDay(@adjusted_date, @p_calendar_id) = 0
                    SET @adjusted_date = DATEADD(DAY, -1, @adjusted_date);
                BREAK;
            END
        END
        ELSE IF @p_convention = 'PRECEDING'
            SET @adjusted_date = DATEADD(DAY, -1, @adjusted_date);
        ELSE IF @p_convention = 'MODIFIED_PRECEDING'
        BEGIN
            SET @adjusted_date = DATEADD(DAY, -1, @adjusted_date);
            -- Check if we crossed into previous month
            IF MONTH(@adjusted_date) != @original_month
            BEGIN
                SET @adjusted_date = @p_date;
                WHILE dbo.IsBusinessDay(@adjusted_date, @p_calendar_id) = 0
                    SET @adjusted_date = DATEADD(DAY, 1, @adjusted_date);
                BREAK;
            END
        END
    END
    
    RETURN @adjusted_date;
END;
GO

-- =============================================================================
-- SCHEDULE GENERATION PROCEDURES
-- =============================================================================

-- Main schedule generation procedure
CREATE OR ALTER PROCEDURE dbo.GenerateSchedule
    @p_schedule_id VARCHAR(50),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_frequency_code VARCHAR(20),
    @p_convention_code VARCHAR(30) = 'MODIFIED_FOLLOWING',
    @p_calendar_id VARCHAR(50) = 'USNY',
    @p_first_regular_start_date DATE = NULL,
    @p_last_regular_end_date DATE = NULL,
    @p_stub_code VARCHAR(30) = 'NONE',
    @p_roll_code VARCHAR(20) = 'EOM'
AS
BEGIN
    -- Create temporary table for results
    CREATE TABLE #SchedulePeriods (
        period_number INT,
        start_date DATE,
        end_date DATE,
        adjusted_start_date DATE,
        adjusted_end_date DATE,
        period_type VARCHAR(20),
        days_in_period INT
    );
    
    DECLARE @months_increment INT;
    DECLARE @days_increment INT;
    DECLARE @period_number INT = 1;
    DECLARE @current_date DATE = @p_start_date;
    DECLARE @next_date DATE;
    DECLARE @total_periods INT;
    
    -- Get frequency parameters
    SELECT @months_increment = months_increment, @days_increment = days_increment
    FROM ScheduleFrequency
    WHERE frequency_code = @p_frequency_code;
    
    -- Handle terminal frequency
    IF @p_frequency_code = 'TERMINAL'
    BEGIN
        INSERT INTO #SchedulePeriods VALUES (
            1,
            @p_start_date,
            @p_end_date,
            dbo.AdjustBusinessDay(@p_start_date, @p_convention_code, @p_calendar_id),
            dbo.AdjustBusinessDay(@p_end_date, @p_convention_code, @p_calendar_id),
            'REGULAR',
            DATEDIFF(DAY, @p_start_date, @p_end_date)
        );
        
        SELECT * FROM #SchedulePeriods;
        DROP TABLE #SchedulePeriods;
        RETURN;
    END
    
    -- Estimate total periods
    SET @total_periods = CEILING(DATEDIFF(DAY, @p_start_date, @p_end_date) / 30.0);
    
    -- Generate periods
    WHILE @current_date < @p_end_date
    BEGIN
        -- Calculate next period end
        IF @months_increment IS NOT NULL
        BEGIN
            SET @next_date = DATEADD(MONTH, @months_increment, @current_date);
            
            -- Adjust based on roll convention
            IF @p_roll_code = 'EOM'
                SET @next_date = EOMONTH(@next_date);
            ELSE IF @p_roll_code = 'DAY_1'
                SET @next_date = DATEFROMPARTS(YEAR(@next_date), MONTH(@next_date), 1);
            ELSE IF @p_roll_code = 'DAY_15'
                SET @next_date = DATEFROMPARTS(YEAR(@next_date), MONTH(@next_date), 15);
            ELSE IF @p_roll_code = 'DAY_30'
                SET @next_date = DATEFROMPARTS(YEAR(@next_date), MONTH(@next_date), 30);
        END
        ELSE IF @days_increment IS NOT NULL
        BEGIN
            SET @next_date = DATEADD(DAY, @days_increment, @current_date);
        END
        
        -- Ensure we don't exceed end date
        IF @next_date > @p_end_date
            SET @next_date = @p_end_date;
        
        -- Determine period type
        DECLARE @period_type VARCHAR(20) = 'REGULAR';
        
        IF @period_number = 1 AND @current_date != ISNULL(@p_first_regular_start_date, @current_date)
            SET @period_type = 'INITIAL_STUB';
        ELSE IF @next_date = @p_end_date AND @next_date != ISNULL(@p_last_regular_end_date, @next_date)
            SET @period_type = 'FINAL_STUB';
        
        -- Insert the period
        INSERT INTO #SchedulePeriods VALUES (
            @period_number,
            @current_date,
            @next_date,
            dbo.AdjustBusinessDay(@current_date, @p_convention_code, @p_calendar_id),
            dbo.AdjustBusinessDay(@next_date, @p_convention_code, @p_calendar_id),
            @period_type,
            DATEDIFF(DAY, @current_date, @next_date)
        );
        
        -- Move to next period
        SET @current_date = @next_date;
        SET @period_number = @period_number + 1;
        
        -- Exit if we've reached the end
        IF @current_date >= @p_end_date
            BREAK;
    END
    
    SELECT * FROM #SchedulePeriods;
    DROP TABLE #SchedulePeriods;
END;
GO

-- =============================================================================
-- COMPLETE SCHEDULE CREATION PROCEDURE
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.CreateCompleteSchedule
    @p_schedule_name VARCHAR(200),
    @p_schedule_type VARCHAR(30),
    @p_start_date DATE,
    @p_end_date DATE,
    @p_frequency_code VARCHAR(20),
    @p_convention_code VARCHAR(30) = 'MODIFIED_FOLLOWING',
    @p_calendar_id VARCHAR(50) = 'USNY',
    @p_event_type VARCHAR(30) = 'PAYMENT',
    @p_events_per_period INT = 1,
    @p_new_schedule_id VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Generate schedule ID
    SET @p_new_schedule_id = 'SCH_' + CONVERT(VARCHAR(20), GETDATE(), 112) + 
                           REPLACE(CONVERT(VARCHAR(20), GETDATE(), 114), ':', '') + 
                           RIGHT(CONVERT(VARCHAR(36), NEWID()), 8);
    
    -- Insert schedule definition
    INSERT INTO ScheduleDefinition (
        schedule_id, schedule_name, schedule_type, 
        start_date, end_date, frequency_code, convention_code,
        business_centers
    ) VALUES (
        @p_new_schedule_id, @p_schedule_name, @p_schedule_type,
        @p_start_date, @p_end_date, @p_frequency_code, @p_convention_code,
        @p_calendar_id
    );
    
    -- Create temporary table for periods
    CREATE TABLE #GeneratedPeriods (
        period_number INT,
        start_date DATE,
        end_date DATE,
        adjusted_start_date DATE,
        adjusted_end_date DATE,
        period_type VARCHAR(20),
        days_in_period INT
    );
    
    -- Generate periods
    INSERT INTO #GeneratedPeriods
    EXEC dbo.GenerateSchedule
        @p_schedule_id = @p_new_schedule_id,
        @p_start_date = @p_start_date,
        @p_end_date = @p_end_date,
        @p_frequency_code = @p_frequency_code,
        @p_convention_code = @p_convention_code,
        @p_calendar_id = @p_calendar_id;
    
    -- Insert periods
    INSERT INTO SchedulePeriod (
        period_id, schedule_id, start_date, end_date,
        adjusted_start_date, adjusted_end_date, period_type,
        period_number, total_periods, days_in_period, is_stub
    )
    SELECT 
        @p_new_schedule_id + '_P' + RIGHT('000' + CAST(period_number AS VARCHAR), 3),
        @p_new_schedule_id,
        start_date,
        end_date,
        adjusted_start_date,
        adjusted_end_date,
        period_type,
        period_number,
        (SELECT COUNT(*) FROM #GeneratedPeriods),
        days_in_period,
        CASE WHEN period_type LIKE '%STUB%' THEN 1 ELSE 0 END
    FROM #GeneratedPeriods;
    
    -- Generate and insert events
    DECLARE @period_cursor CURSOR;
    DECLARE @period_id VARCHAR(50);
    DECLARE @period_end_date DATE;
    DECLARE @event_number INT = 1;
    
    SET @period_cursor = CURSOR FOR
        SELECT period_id, adjusted_end_date
        FROM SchedulePeriod
        WHERE schedule_id = @p_new_schedule_id
        ORDER BY period_number;
    
    OPEN @period_cursor;
    FETCH NEXT FROM @period_cursor INTO @period_id, @period_end_date;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO ScheduleEvent (
            event_id, period_id, schedule_id, event_date,
            adjusted_event_date, event_type, event_number, total_events
        ) VALUES (
            @p_new_schedule_id + '_E' + RIGHT('0000' + CAST(@event_number AS VARCHAR), 4),
            @period_id,
            @p_new_schedule_id,
            @period_end_date,
            @period_end_date,
            @p_event_type,
            @event_number,
            (SELECT COUNT(*) FROM SchedulePeriod WHERE schedule_id = @p_new_schedule_id)
        );
        
        SET @event_number = @event_number + 1;
        FETCH NEXT FROM @period_cursor INTO @period_id, @period_end_date;
    END
    
    CLOSE @period_cursor;
    DEALLOCATE @period_cursor;
    
    DROP TABLE #GeneratedPeriods;
END;
GO

-- =============================================================================
-- BUSINESS CALENDAR SETUP
-- =============================================================================

-- Insert standard business calendars
INSERT INTO BusinessCalendar (calendar_id, calendar_name, business_center_code, country_code, weekend_days) VALUES
('USNY', 'New York', 'USNY', 'US', '1,7'),
('GBLO', 'London', 'GBLO', 'GB', '1,7'),
('EUTA', 'Euro TARGET', 'EUTA', 'EU', '1,7'),
('JPTO', 'Tokyo', 'JPTO', 'JP', '1,7'),
('AUSY', 'Sydney', 'AUSY', 'AU', '1,7'),
('HKHK', 'Hong Kong', 'HKHK', 'HK', '1,7'),
('SGSI', 'Singapore', 'SGSI', 'SG', '1,7');

-- Insert sample holidays (US New York)
INSERT INTO HolidayDate (holiday_id, calendar_id, holiday_date, holiday_name, holiday_type) VALUES
('HOL_US_001', 'USNY', '2024-01-01', 'New Year''s Day', 'PUBLIC'),
('HOL_US_002', 'USNY', '2024-01-15', 'Martin Luther King Jr. Day', 'PUBLIC'),
('HOL_US_003', 'USNY', '2024-02-19', 'Presidents Day', 'PUBLIC'),
('HOL_US_004', 'USNY', '2024-05-27', 'Memorial Day', 'PUBLIC'),
('HOL_US_005', 'USNY', '2024-07-04', 'Independence Day', 'PUBLIC'),
('HOL_US_006', 'USNY', '2024-09-02', 'Labor Day', 'PUBLIC'),
('HOL_US_007', 'USNY', '2024-11-28', 'Thanksgiving Day', 'PUBLIC'),
('HOL_US_008', 'USNY', '2024-11-29', 'Thanksgiving Friday', 'PUBLIC'),
('HOL_US_009', 'USNY', '2024-12-25', 'Christmas Day', 'PUBLIC');

-- Insert UK holidays
INSERT INTO HolidayDate (holiday_id, calendar_id, holiday_date, holiday_name, holiday_type) VALUES
('HOL_UK_001', 'GBLO', '2024-01-01', 'New Year''s Day', 'PUBLIC'),
('HOL_UK_002', 'GBLO', '2024-03-29', 'Good Friday', 'PUBLIC'),
('HOL_UK_003', 'GBLO', '2024-04-01', 'Easter Monday', 'PUBLIC'),
('HOL_UK_004', 'GBLO', '2024-05-06', 'Early May Bank Holiday', 'PUBLIC'),
('HOL_UK_005', 'GBLO', '2024-05-27', 'Spring Bank Holiday', 'PUBLIC'),
('HOL_UK_006', 'GBLO', '2024-08-26', 'Summer Bank Holiday', 'PUBLIC'),
('HOL_UK_007', 'GBLO', '2024-12-25', 'Christmas Day', 'PUBLIC'),
('HOL_UK_008', 'GBLO', '2024-12-26', 'Boxing Day', 'PUBLIC');

-- =============================================================================
-- UTILITY VIEWS
-- =============================================================================

-- Complete schedule view
CREATE OR ALTER VIEW schedule_overview AS
SELECT 
    sd.schedule_id,
    sd.schedule_name,
    sd.schedule_type,
    sd.start_date,
    sd.end_date,
    sf.frequency_name as frequency,
    bc.convention_name as business_day_convention,
    sc.stub_name as stub_convention,
    rc.roll_name as roll_convention,
    COUNT(DISTINCT sp.period_id) AS total_periods,
    COUNT(DISTINCT se.event_id) AS total_events,
    MIN(sp.adjusted_start_date) AS first_period_start,
    MAX(sp.adjusted_end_date) AS last_period_end,
    sd.created_datetime
FROM ScheduleDefinition sd
LEFT JOIN SchedulePeriod sp ON sd.schedule_id = sp.schedule_id
LEFT JOIN ScheduleEvent se ON sd.schedule_id = se.schedule_id
LEFT JOIN ScheduleFrequency sf ON sd.frequency_code = sf.frequency_code
LEFT JOIN BusinessDayConvention bc ON sd.convention_code = bc.convention_code
LEFT JOIN StubConvention sc ON sd.stub_code = sc.stub_code
LEFT JOIN RollConvention rc ON sd.roll_code = rc.roll_code
GROUP BY sd.schedule_id, sd.schedule_name, sd.schedule_type, sd.start_date, 
         sd.end_date, sf.frequency_name, bc.convention_name, sc.stub_name, 
         rc.roll_name, sd.created_datetime;

-- Schedule details with periods and events
CREATE OR ALTER VIEW schedule_details AS
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
    sp.is_stub,
    se.event_number,
    se.event_date,
    se.adjusted_event_date,
    se.event_type,
    se.event_subtype,
    se.status,
    se.created_datetime
FROM ScheduleDefinition sd
JOIN SchedulePeriod sp ON sd.schedule_id = sp.schedule_id
LEFT JOIN ScheduleEvent se ON sp.period_id = se.period_id
ORDER BY sd.schedule_id, sp.period_number, se.event_number;

-- =============================================================================
-- VALIDATION PROCEDURES
-- =============================================================================

CREATE OR ALTER PROCEDURE dbo.ValidateSchedule
    @p_schedule_id VARCHAR(50)
AS
BEGIN
    -- Check for overlapping periods
    SELECT 
        'OVERLAPPING_PERIODS' as validation_type,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM SchedulePeriod sp1
                JOIN SchedulePeriod sp2 ON sp1.schedule_id = sp2.schedule_id
                WHERE sp1.schedule_id = @p_schedule_id
                  AND sp1.period_id != sp2.period_id
                  AND sp1.adjusted_start_date <= sp2.adjusted_end_date
                  AND sp2.adjusted_start_date <= sp1.adjusted_end_date
            ) THEN 'FAIL: Overlapping periods found'
            ELSE 'PASS: No overlapping periods'
        END as validation_message;
    
    -- Check for gaps in schedule
    SELECT 
        'GAPS_IN_SCHEDULE' as validation_type,
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM SchedulePeriod sp1
                JOIN SchedulePeriod sp2 ON sp1.schedule_id = sp2.schedule_id
                WHERE sp1.schedule_id = @p_schedule_id
                  AND sp1.period_number = sp2.period_number - 1
                  AND sp1.adjusted_end_date != sp2.adjusted_start_date
            ) THEN 'FAIL: Gaps found in schedule'
            ELSE 'PASS: No gaps in schedule'
        END as validation_message;
    
    -- Check for proper date ordering
    SELECT 
        'DATE_ORDERING' as validation_type,
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM SchedulePeriod
                WHERE schedule_id = @p_schedule_id
                  AND adjusted_start_date >= adjusted_end_date
            ) THEN 'FAIL: Invalid date ordering'
            ELSE 'PASS: Proper date ordering'
        END as validation_message;
END;
GO

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

-- Example 1: Create a simple monthly payment schedule
DECLARE @schedule_id VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Monthly Payments - MS SQL',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-15',
    @p_end_date = '2025-01-15',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @schedule_id OUTPUT;

SELECT @schedule_id AS created_schedule_id;

-- Example 2: Generate schedule periods manually
EXEC dbo.GenerateSchedule
    @p_schedule_id = 'MANUAL_TEST',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'QUARTERLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY';

-- View schedule overview
SELECT * FROM schedule_overview;

-- View schedule details
SELECT * FROM schedule_details WHERE schedule_name LIKE '%MS SQL%';

-- Validate schedule
EXEC dbo.ValidateSchedule @p_schedule_id = @schedule_id;

SELECT 'MS SQL Server Schedule Creation System Created Successfully' AS status;
