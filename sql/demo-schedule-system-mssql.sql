-- =============================================================================
-- MS SQL SERVER SCHEDULE SYSTEM DEMONSTRATION
-- =============================================================================
-- Comprehensive demonstration of the MS SQL Server compatible
-- schedule creation system inspired by OpenGamma Strata
-- =============================================================================

-- =============================================================================
-- DEMONSTRATION SETUP
-- =============================================================================

USE equity_swap_db;
GO

-- Ensure we're using the correct database
SELECT 'MS SQL Server Schedule System Demonstration' AS demo_title,
       GETDATE() as demo_timestamp,
       DB_NAME() as current_database;

-- =============================================================================
-- BASIC SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Example 1: Simple Monthly Payment Schedule
PRINT '=== Example 1: Simple Monthly Payment Schedule ===';

DECLARE @monthly_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Monthly Payments',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-15',
    @p_end_date = '2025-01-15',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @monthly_schedule OUTPUT;

SELECT * FROM schedule_overview WHERE schedule_id = @monthly_schedule;
SELECT * FROM schedule_details WHERE schedule_id = @monthly_schedule ORDER BY period_number, event_number;

-- Example 2: Quarterly Reset Schedule
PRINT '=== Example 2: Quarterly Reset Schedule ===';

DECLARE @quarterly_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Quarterly Resets',
    @p_schedule_type = 'RESET',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'QUARTERLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'RESET',
    @p_events_per_period = 1,
    @p_new_schedule_id = @quarterly_schedule OUTPUT;

SELECT * FROM schedule_overview WHERE schedule_id = @quarterly_schedule;

-- =============================================================================
-- ADVANCED SCHEDULE FEATURES
-- =============================================================================

-- Example 3: Stub Period Handling
PRINT '=== Example 3: Stub Period Handling ===';

DECLARE @stub_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Stub Period Schedule',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-10',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @stub_schedule OUTPUT;

-- Show stub periods
SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    days_in_period,
    CASE 
        WHEN period_type = 'INITIAL_STUB' THEN 'Short initial period'
        WHEN period_type = 'FINAL_STUB' THEN 'Short final period'
        ELSE 'Regular monthly period'
    END as description
FROM SchedulePeriod 
WHERE schedule_id = @stub_schedule
ORDER BY period_number;

-- Example 4: Multi-Region Calendar Comparison
PRINT '=== Example 4: Multi-Region Calendar Comparison ===';

-- US NY Schedule
DECLARE @us_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: US NY Calendar',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-07-01',
    @p_end_date = '2024-07-31',
    @p_frequency_code = 'WEEKLY',
    @p_convention_code = 'FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @us_schedule OUTPUT;

-- London Schedule
DECLARE @uk_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: London Calendar',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-07-01',
    @p_end_date = '2024-07-31',
    @p_frequency_code = 'WEEKLY',
    @p_convention_code = 'FOLLOWING',
    @p_calendar_id = 'GBLO',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @uk_schedule OUTPUT;

-- Compare calendars
SELECT 
    'US NY' as calendar,
    event_date as original_date,
    adjusted_event_date as adjusted_date,
    event_type
FROM ScheduleEvent se
JOIN SchedulePeriod sp ON se.period_id = sp.period_id
WHERE sp.schedule_id = @us_schedule

UNION ALL

SELECT 
    'London' as calendar,
    event_date as original_date,
    adjusted_event_date as adjusted_date,
    event_type
FROM ScheduleEvent se
JOIN SchedulePeriod sp ON se.period_id = sp.period_id
WHERE sp.schedule_id = @uk_schedule
ORDER BY calendar, adjusted_date;

-- =============================================================================
-- COMPLEX FINANCIAL INSTRUMENT SCHEDULES
-- =============================================================================

-- Example 5: Equity Swap with Multiple Legs
PRINT '=== Example 5: Complex Equity Swap Schedule ===';

-- Create a comprehensive equity swap schedule
DECLARE @equity_swap_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Equity Swap Leg 1 - Fixed Payments',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-15',
    @p_end_date = '2025-01-15',
    @p_frequency_code = 'SEMI_ANNUAL',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'FIXED_PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @equity_swap_schedule OUTPUT;

-- Create floating leg
DECLARE @floating_leg_schedule VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Equity Swap Leg 2 - Floating Payments',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-15',
    @p_end_date = '2025-01-15',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'FLOATING_PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @floating_leg_schedule OUTPUT;

-- Show both legs
SELECT 
    schedule_name,
    schedule_type,
    frequency,
    total_periods,
    first_period_start = MIN(sp.adjusted_start_date),
    last_period_end = MAX(sp.adjusted_end_date)
FROM schedule_overview so
JOIN SchedulePeriod sp ON so.schedule_id = sp.schedule_id
WHERE so.schedule_id IN (@equity_swap_schedule, @floating_leg_schedule)
GROUP BY schedule_name, schedule_type, frequency, total_periods;

-- =============================================================================
-- BUSINESS DAY ADJUSTMENT DEMONSTRATION
-- =============================================================================

-- Example 6: Business Day Adjustment Effects
PRINT '=== Example 6: Business Day Adjustment Effects ===';

-- Create test dates around holidays
CREATE TABLE #TestDates (
    original_date DATE,
    convention VARCHAR(30),
    calendar_id VARCHAR(50)
);

INSERT INTO #TestDates VALUES
('2024-07-04', 'FOLLOWING', 'USNY'),      -- Independence Day
('2024-07-04', 'MODIFIED_FOLLOWING', 'USNY'),
('2024-11-28', 'FOLLOWING', 'USNY'),      -- Thanksgiving
('2024-11-28', 'MODIFIED_FOLLOWING', 'USNY'),
('2024-12-25', 'PRECEDING', 'USNY'),      -- Christmas
('2024-12-25', 'MODIFIED_PRECEDING', 'USNY');

SELECT 
    original_date,
    DATENAME(WEEKDAY, original_date) as original_weekday,
    convention,
    calendar_id,
    dbo.IsBusinessDay(original_date, calendar_id) as is_business_day,
    dbo.AdjustBusinessDay(original_date, convention, calendar_id) as adjusted_date,
    DATENAME(WEEKDAY, dbo.AdjustBusinessDay(original_date, convention, calendar_id)) as adjusted_weekday,
    CASE 
        WHEN dbo.IsBusinessDay(original_date, calendar_id) = 1 THEN 'No adjustment needed'
        ELSE 'Adjusted to next/previous business day'
    END as adjustment_result
FROM #TestDates
ORDER BY original_date, convention;

DROP TABLE #TestDates;

-- =============================================================================
-- PERFORMANCE BENCHMARKING
-- =============================================================================

-- Example 7: Performance Testing
PRINT '=== Example 7: Performance Benchmarking ===';

-- Measure time for large schedule generation
DECLARE @start_time DATETIME2 = GETDATE();
DECLARE @performance_schedule VARCHAR(50);

EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'Demo: Performance Test',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2020-01-01',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'DAILY',
    @p_convention_code = 'FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @performance_schedule OUTPUT;

DECLARE @end_time DATETIME2 = GETDATE();
DECLARE @duration_ms INT = DATEDIFF(MILLISECOND, @start_time, @end_time);

SELECT 
    schedule_name,
    total_periods,
    total_events,
    @duration_ms as generation_time_ms,
    CAST(@duration_ms / 1000.0 as DECIMAL(10,2)) as generation_time_seconds,
    CASE 
        WHEN @duration_ms < 1000 THEN 'Excellent'
        WHEN @duration_ms < 5000 THEN 'Good'
        WHEN @duration_ms < 10000 THEN 'Acceptable'
        ELSE 'Slow - consider optimization'
    END as performance_rating
FROM schedule_overview 
WHERE schedule_id = @performance_schedule;

-- =============================================================================
-- VALIDATION AND INTEGRITY CHECKS
-- =============================================================================

-- Example 8: Schedule Validation
PRINT '=== Example 8: Schedule Validation ===';

-- Run validation on all demo schedules
DECLARE @validation_cursor CURSOR;
DECLARE @schedule_to_validate VARCHAR(50);

SET @validation_cursor = CURSOR FOR
    SELECT schedule_id 
    FROM ScheduleDefinition 
    WHERE schedule_name LIKE 'Demo:%';

OPEN @validation_cursor;
FETCH NEXT FROM @validation_cursor INTO @schedule_to_validate;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Validating schedule: ' + @schedule_to_validate;
    EXEC dbo.ValidateSchedule @p_schedule_id = @schedule_to_validate;
    FETCH NEXT FROM @validation_cursor INTO @schedule_to_validate;
END

CLOSE @validation_cursor;
DEALLOCATE @validation_cursor;

-- =============================================================================
-- UTILITY QUERIES
-- =============================================================================

-- Example 9: Schedule Analysis Queries
PRINT '=== Example 9: Schedule Analysis Queries ===';

-- Summary of all demo schedules
SELECT 
    'Demo Schedule Summary' as query_type,
    schedule_name,
    schedule_type,
    frequency,
    total_periods,
    total_events,
    DATEDIFF(DAY, start_date, end_date) as total_days,
    CAST(total_periods * 1.0 / DATEDIFF(DAY, start_date, end_date) * 365 as DECIMAL(10,2)) as avg_days_per_period
FROM schedule_overview
WHERE schedule_name LIKE 'Demo:%'
ORDER BY created_datetime DESC;

-- Period analysis by type
SELECT 
    'Period Type Analysis' as query_type,
    schedule_name,
    period_type,
    COUNT(*) as period_count,
    AVG(days_in_period) as avg_days,
    MIN(days_in_period) as min_days,
    MAX(days_in_period) as max_days
FROM schedule_details
WHERE schedule_name LIKE 'Demo:%'
GROUP BY schedule_name, period_type
ORDER BY schedule_name, period_type;

-- Event timeline for a specific schedule
SELECT 
    'Event Timeline' as query_type,
    schedule_name,
    period_number,
    event_number,
    event_date,
    adjusted_event_date,
    event_type,
    status,
    DATENAME(WEEKDAY, adjusted_event_date) as day_of_week
FROM schedule_details
WHERE schedule_name = 'Demo: Monthly Payments'
ORDER BY period_number, event_number;

-- =============================================================================
-- ADVANCED FEATURES DEMONSTRATION
-- =============================================================================

-- Example 10: Complex Financial Instrument Integration
PRINT '=== Example 10: Complex Financial Instrument Integration ===';

-- Create a comprehensive equity swap with all components
DECLARE @master_schedule VARCHAR(50) = 'MASTER_EQ_SWAP_2024';

-- Master schedule definition
IF NOT EXISTS (SELECT 1 FROM ScheduleDefinition WHERE schedule_id = @master_schedule)
BEGIN
    INSERT INTO ScheduleDefinition (
        schedule_id, schedule_name, schedule_type, 
        start_date, end_date, frequency_code, convention_code,
        business_centers, created_datetime
    ) VALUES (
        @master_schedule, 'Demo: Master Equity Swap Schedule', 'MASTER',
        '2024-01-15', '2025-01-15', 'MONTHLY', 'MODIFIED_FOLLOWING',
        'USNY,GBLO', GETDATE()
    );

    -- Create sub-schedules for different legs
    DECLARE @fixed_leg VARCHAR(50);
    DECLARE @floating_leg VARCHAR(50);
    DECLARE @reset_leg VARCHAR(50);
    DECLARE @observation_leg VARCHAR(50);

    -- Fixed leg
    EXEC dbo.CreateCompleteSchedule
        @p_schedule_name = 'Demo: Fixed Leg Payments',
        @p_schedule_type = 'PAYMENT',
        @p_start_date = '2024-01-15',
        @p_end_date = '2025-01-15',
        @p_frequency_code = 'SEMI_ANNUAL',
        @p_convention_code = 'MODIFIED_FOLLOWING',
        @p_calendar_id = 'USNY',
        @p_event_type = 'FIXED_PAYMENT',
        @p_events_per_period = 1,
        @p_new_schedule_id = @fixed_leg OUTPUT;

    -- Floating leg
    EXEC dbo.CreateCompleteSchedule
        @p_schedule_name = 'Demo: Floating Leg Payments',
        @p_schedule_type = 'PAYMENT',
        @p_start_date = '2024-01-15',
        @p_end_date = '2025-01-15',
        @p_frequency_code = 'MONTHLY',
        @p_convention_code = 'MODIFIED_FOLLOWING',
        @p_calendar_id = 'USNY',
        @p_event_type = 'FLOATING_PAYMENT',
        @p_events_per_period = 1,
        @p_new_schedule_id = @floating_leg OUTPUT;

    -- Reset schedule
    EXEC dbo.CreateCompleteSchedule
        @p_schedule_name = 'Demo: Reset Schedule',
        @p_schedule_type = 'RESET',
        @p_start_date = '2024-01-15',
        @p_end_date = '2025-01-15',
        @p_frequency_code = 'MONTHLY',
        @p_convention_code = 'MODIFIED_FOLLOWING',
        @p_calendar_id = 'USNY',
        @p_event_type = 'RESET',
        @p_events_per_period = 1,
        @p_new_schedule_id = @reset_leg OUTPUT;

    -- Observation schedule
    EXEC dbo.CreateCompleteSchedule
        @p_schedule_name = 'Demo: Observation Schedule',
        @p_schedule_type = 'OBSERVATION',
        @p_start_date = '2024-01-15',
        @p_end_date = '2025-01-15',
        @p_frequency_code = 'DAILY',
        @p_convention_code = 'FOLLOWING',
        @p_calendar_id = 'USNY',
        @p_event_type = 'OBSERVATION',
        @p_events_per_period = 1,
        @p_new_schedule_id = @observation_leg OUTPUT;

    -- Show integrated schedule
    SELECT 
        'Integrated Equity Swap' as instrument_type,
        schedule_name,
        schedule_type,
        frequency,
        total_periods,
        first_period_start = MIN(sp.adjusted_start_date),
        last_period_end = MAX(sp.adjusted_end_date)
    FROM schedule_overview so
    JOIN SchedulePeriod sp ON so.schedule_id = sp.schedule_id
    WHERE so.schedule_id IN (@fixed_leg, @floating_leg, @reset_leg, @observation_leg)
    GROUP BY schedule_name, schedule_type, frequency, total_periods
    ORDER BY schedule_type;
END

-- =============================================================================
-- CLEANUP AND FINAL SUMMARY
-- =============================================================================

-- Summary of all demonstration schedules
SELECT 
    '=== MS SQL Server Schedule System Demonstration Complete ===' as summary_title,
    COUNT(*) as total_schedules_created,
    COUNT(DISTINCT schedule_type) as schedule_types,
    MIN(created_datetime) as first_created,
    MAX(created_datetime) as last_created
FROM schedule_overview
WHERE schedule_name LIKE 'Demo:%';

-- Final schedule overview
SELECT 
    schedule_name,
    schedule_type,
    frequency,
    business_day_convention,
    total_periods,
    total_events,
    created_datetime
FROM schedule_overview
WHERE schedule_name LIKE 'Demo:%'
ORDER BY created_datetime DESC;

SELECT 'MS SQL Server Schedule System Demonstration Complete' AS status;
