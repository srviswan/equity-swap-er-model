-- =============================================================================
-- MS SQL SERVER TEST DATA FOR SCHEDULE CREATION SYSTEM
-- =============================================================================
-- This file contains comprehensive test cases for the MS SQL Server
-- compatible schedule generation system inspired by OpenGamma Strata
-- =============================================================================

-- =============================================================================
-- SAMPLE EQUITY SWAP DATA
-- =============================================================================

-- Insert sample equity swap trades for schedule testing
IF NOT EXISTS (SELECT 1 FROM Trade WHERE trade_id = 'TRADE_001')
BEGIN
    INSERT INTO Trade (trade_id, product_id, trade_date, trade_time, status, 
                       activity_quantity, activity_notional, settlement_date, 
                       settlement_amount, direction, created_timestamp) VALUES
    ('TRADE_001', 'EQ_SWAP_001', '2024-01-15', '2024-01-15 10:30:00', 'ACTIVE', 
     1000.00, 100000.00, '2024-01-17', 100000.00, 'LONG', GETDATE()),
    ('TRADE_002', 'EQ_SWAP_002', '2024-02-01', '2024-02-01 14:15:00', 'ACTIVE', 
     5000.00, 500000.00, '2024-02-05', 500000.00, 'SHORT', GETDATE()),
    ('TRADE_003', 'EQ_SWAP_003', '2024-03-10', '2024-03-10 09:45:00', 'ACTIVE', 
     2500.00, 250000.00, '2024-03-12', 250000.00, 'LONG', GETDATE());
END

-- Insert sample economic terms for schedule references
IF NOT EXISTS (SELECT 1 FROM EconomicTerms WHERE economic_terms_id = 'ECON_001')
BEGIN
    INSERT INTO EconomicTerms (economic_terms_id, product_id, effective_date, termination_date,
                              business_day_convention, business_centers) VALUES
    ('ECON_001', 'EQ_SWAP_001', '2024-01-15', '2025-01-15', 'MODIFIED_FOLLOWING', 'USNY'),
    ('ECON_002', 'EQ_SWAP_002', '2024-02-01', '2024-08-01', 'MODIFIED_FOLLOWING', 'USNY'),
    ('ECON_003', 'EQ_SWAP_003', '2024-03-10', '2024-09-10', 'MODIFIED_FOLLOWING', 'USNY');
END

-- =============================================================================
-- SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Example 1: Monthly Payment Schedule for Equity Swap
DECLARE @schedule_id1 VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Monthly Payments',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-15',
    @p_end_date = '2025-01-15',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @schedule_id1 OUTPUT;

SELECT @schedule_id1 AS monthly_schedule_id;

-- Example 2: Quarterly Reset Schedule
DECLARE @schedule_id2 VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Quarterly Resets',
    @p_schedule_type = 'RESET',
    @p_start_date = '2024-02-01',
    @p_end_date = '2024-08-01',
    @p_frequency_code = 'QUARTERLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'RESET',
    @p_events_per_period = 1,
    @p_new_schedule_id = @schedule_id2 OUTPUT;

SELECT @schedule_id2 AS quarterly_schedule_id;

-- Example 3: Weekly Observation Schedule
DECLARE @schedule_id3 VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Weekly Observations',
    @p_schedule_type = 'OBSERVATION',
    @p_start_date = '2024-03-10',
    @p_end_date = '2024-09-10',
    @p_frequency_code = 'WEEKLY',
    @p_convention_code = 'FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'OBSERVATION',
    @p_events_per_period = 1,
    @p_new_schedule_id = @schedule_id3 OUTPUT;

SELECT @schedule_id3 AS weekly_schedule_id;

-- =============================================================================
-- MANUAL SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Manual schedule creation for more control
IF NOT EXISTS (SELECT 1 FROM ScheduleDefinition WHERE schedule_id = 'SCH_CUSTOM_MSSQL_001')
BEGIN
    INSERT INTO ScheduleDefinition (
        schedule_id, schedule_name, schedule_type, 
        start_date, end_date, frequency_code, convention_code,
        first_regular_start_date, last_regular_end_date,
        stub_code, roll_code, business_centers
    ) VALUES 
    ('SCH_CUSTOM_MSSQL_001', 'MS SQL Custom Monthly with Stubs', 'PAYMENT', 
     '2024-01-15', '2024-12-15', 'MONTHLY', 'MODIFIED_FOLLOWING',
     '2024-02-15', '2024-11-15', 'SHORT_INITIAL', 'SHORT_FINAL', 'EOM');

    -- Generate periods for custom schedule
    CREATE TABLE #CustomPeriods (
        period_number INT,
        start_date DATE,
        end_date DATE,
        adjusted_start_date DATE,
        adjusted_end_date DATE,
        period_type VARCHAR(20),
        days_in_period INT
    );

    INSERT INTO #CustomPeriods
    EXEC dbo.GenerateSchedule
        @p_schedule_id = 'SCH_CUSTOM_MSSQL_001',
        @p_start_date = '2024-01-15',
        @p_end_date = '2024-12-15',
        @p_frequency_code = 'MONTHLY',
        @p_convention_code = 'MODIFIED_FOLLOWING',
        @p_calendar_id = 'USNY';

    -- Insert the periods
    INSERT INTO SchedulePeriod (
        period_id, schedule_id, start_date, end_date,
        adjusted_start_date, adjusted_end_date, period_type,
        period_number, total_periods, days_in_period, is_stub
    )
    SELECT 
        'SCH_CUSTOM_MSSQL_001_P' + RIGHT('000' + CAST(period_number AS VARCHAR), 3),
        'SCH_CUSTOM_MSSQL_001',
        start_date,
        end_date,
        adjusted_start_date,
        adjusted_end_date,
        period_type,
        period_number,
        (SELECT COUNT(*) FROM #CustomPeriods),
        days_in_period,
        CASE WHEN period_type LIKE '%STUB%' THEN 1 ELSE 0 END
    FROM #CustomPeriods;

    DROP TABLE #CustomPeriods;
END

-- =============================================================================
-- BUSINESS CALENDAR EXTENSIONS
-- =============================================================================

-- Add more business centers
IF NOT EXISTS (SELECT 1 FROM BusinessCalendar WHERE calendar_id = 'GBLO')
BEGIN
    INSERT INTO BusinessCalendar (calendar_id, calendar_name, business_center_code, country_code, weekend_days) VALUES
    ('GBLO', 'London', 'GBLO', 'GB', '1,7'),
    ('EUTA', 'Euro TARGET', 'EUTA', 'EU', '1,7'),
    ('JPTO', 'Tokyo', 'JPTO', 'JP', '1,7'),
    ('HKHK', 'Hong Kong', 'HKHK', 'HK', '1,7'),
    ('SGSI', 'Singapore', 'SGSI', 'SG', '1,7');

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
END

-- =============================================================================
-- VALIDATION TESTS
-- =============================================================================

-- Test 1: Validate schedule generation
SELECT '=== MS SQL Test 1: Schedule Validation ===' AS test_description;

DECLARE @test_schedule_id VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Test Validation',
    @p_schedule_type = 'PAYMENT',
    @p_start_date = '2024-01-01',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'MONTHLY',
    @p_new_schedule_id = @test_schedule_id OUTPUT;

SELECT @test_schedule_id AS test_schedule_id;

-- View the generated schedule
SELECT 
    schedule_id,
    schedule_name,
    schedule_type,
    start_date,
    end_date,
    frequency,
    business_day_convention,
    total_periods,
    total_events
FROM schedule_overview 
WHERE schedule_name = 'MS SQL Test Validation';

-- Test 2: Check business day adjustment
SELECT '=== MS SQL Test 2: Business Day Adjustments ===' AS test_description;

SELECT 
    original_date,
    convention_code,
    adjusted_date,
    calendar_id,
    dbo.IsBusinessDay(adjusted_date, calendar_id) as is_business_day
FROM (
    SELECT 
        '2024-07-04' as original_date,
        'MODIFIED_FOLLOWING' as convention_code,
        dbo.AdjustBusinessDay('2024-07-04', 'MODIFIED_FOLLOWING', 'USNY') as adjusted_date,
        'USNY' as calendar_id
) test_dates;

-- Test 3: Complex stub handling
SELECT '=== MS SQL Test 3: Stub Period Handling ===' AS test_description;

SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    days_in_period,
    is_stub,
    CASE 
        WHEN period_type = 'INITIAL_STUB' THEN 'First period is shorter'
        WHEN period_type = 'FINAL_STUB' THEN 'Last period is shorter'
        ELSE 'Regular period'
    END as description
FROM SchedulePeriod 
WHERE schedule_id = 'SCH_CUSTOM_MSSQL_001'
ORDER BY period_number;

-- Test 4: Multi-calendar validation
SELECT '=== MS SQL Test 4: Multi-Calendar Validation ===' AS test_description;

SELECT 
    date_to_check,
    calendar_id,
    dbo.IsBusinessDay(date_to_check, calendar_id) as is_business_day,
    CASE 
        WHEN dbo.IsBusinessDay(date_to_check, calendar_id) = 1 THEN 'Business Day'
        ELSE 'Holiday/Weekend'
    END as status
FROM (
    SELECT 
        DATEADD(DAY, number, '2024-12-23') as date_to_check,
        'USNY' as calendar_id
    FROM master..spt_values 
    WHERE type = 'P' AND number BETWEEN 0 AND 8
    
    UNION ALL
    
    SELECT 
        DATEADD(DAY, number, '2024-12-23') as date_to_check,
        'GBLO' as calendar_id
    FROM master..spt_values 
    WHERE type = 'P' AND number BETWEEN 0 AND 8
) calendar_check
ORDER BY calendar_id, date_to_check;

-- =============================================================================
-- PERFORMANCE TESTS
-- =============================================================================

-- Test large schedule generation
SELECT '=== MS SQL Test 5: Performance Testing ===' AS test_description;

DECLARE @large_schedule_id VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Large Daily Schedule',
    @p_schedule_type = 'OBSERVATION',
    @p_start_date = '2020-01-01',
    @p_end_date = '2024-12-31',
    @p_frequency_code = 'DAILY',
    @p_convention_code = 'FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'OBSERVATION',
    @p_events_per_period = 1,
    @p_new_schedule_id = @large_schedule_id OUTPUT;

SELECT @large_schedule_id AS large_schedule_id;

-- Analyze the generated schedule
SELECT 
    schedule_name,
    start_date,
    end_date,
    frequency,
    total_periods,
    total_events,
    CAST(total_periods AS DECIMAL) / DATEDIFF(DAY, start_date, end_date) * 365 as avg_days_per_period
FROM schedule_overview 
WHERE schedule_name = 'MS SQL Large Daily Schedule';

-- =============================================================================
-- EDGE CASE TESTS
-- =============================================================================

-- Test: Single day schedule
SELECT '=== MS SQL Test 6: Edge Cases ===' AS test_description;

DECLARE @single_day_id VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Single Day',
    @p_schedule_type = 'TERMINAL',
    @p_start_date = '2024-06-15',
    @p_end_date = '2024-06-15',
    @p_frequency_code = 'TERMINAL',
    @p_convention_code = 'NO_ADJUST',
    @p_calendar_id = 'USNY',
    @p_event_type = 'SETTLEMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @single_day_id OUTPUT;

SELECT @single_day_id AS single_day_schedule;

-- Test: Leap year handling
DECLARE @leap_year_id VARCHAR(50);
EXEC dbo.CreateCompleteSchedule
    @p_schedule_name = 'MS SQL Leap Year',
    @p_schedule_type = 'MONTHLY',
    @p_start_date = '2024-02-28',
    @p_end_date = '2024-03-31',
    @p_frequency_code = 'MONTHLY',
    @p_convention_code = 'MODIFIED_FOLLOWING',
    @p_calendar_id = 'USNY',
    @p_event_type = 'PAYMENT',
    @p_events_per_period = 1,
    @p_new_schedule_id = @leap_year_id OUTPUT;

SELECT @leap_year_id AS leap_year_schedule;

-- =============================================================================
-- VALIDATION SUMMARY
-- =============================================================================

-- Final validation of all created schedules
SELECT '=== MS SQL Final Validation Summary ===' AS summary_description;

SELECT 
    schedule_id,
    schedule_name,
    schedule_type,
    start_date,
    end_date,
    frequency,
    total_periods,
    total_events,
    CASE 
        WHEN total_periods > 0 THEN 'VALID'
        ELSE 'INVALID'
    END as validation_status
FROM schedule_overview
WHERE schedule_name LIKE '%MS SQL%'
ORDER BY created_datetime DESC;

-- Run validation on test schedules
DECLARE @validation_schedule VARCHAR(50) = (SELECT TOP 1 schedule_id FROM schedule_overview WHERE schedule_name LIKE '%MS SQL Test%');
IF @validation_schedule IS NOT NULL
BEGIN
    EXEC dbo.ValidateSchedule @p_schedule_id = @validation_schedule;
END

SELECT 'MS SQL Server Schedule Test Data Created Successfully' AS status;
