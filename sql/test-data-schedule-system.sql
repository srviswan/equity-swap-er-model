-- =============================================================================
-- TEST DATA FOR SCHEDULE CREATION SYSTEM
-- =============================================================================
-- This file contains comprehensive test cases for the schedule generation system
-- inspired by OpenGamma Strata PeriodicSchedule
-- =============================================================================

-- =============================================================================
-- SAMPLE EQUITY SWAP DATA
-- =============================================================================

-- Insert sample equity swap trades for schedule testing
INSERT INTO Trade (trade_id, product_id, trade_date, trade_time, status, 
                   activity_quantity, activity_notional, settlement_date, 
                   settlement_amount, direction, created_timestamp) VALUES
('TRADE_001', 'EQ_SWAP_001', '2024-01-15', '2024-01-15 10:30:00', 'ACTIVE', 
 1000.00, 100000.00, '2024-01-17', 100000.00, 'LONG', NOW()),
('TRADE_002', 'EQ_SWAP_002', '2024-02-01', '2024-02-01 14:15:00', 'ACTIVE', 
 5000.00, 500000.00, '2024-02-05', 500000.00, 'SHORT', NOW()),
('TRADE_003', 'EQ_SWAP_003', '2024-03-10', '2024-03-10 09:45:00', 'ACTIVE', 
 2500.00, 250000.00, '2024-03-12', 250000.00, 'LONG', NOW());

-- Insert sample economic terms for schedule references
INSERT INTO EconomicTerms (economic_terms_id, product_id, effective_date, termination_date,
                          business_day_convention, business_centers) VALUES
('ECON_001', 'EQ_SWAP_001', '2024-01-15', '2025-01-15', 'MODIFIED_FOLLOWING', '["USNY"]'),
('ECON_002', 'EQ_SWAP_002', '2024-02-01', '2024-08-01', 'MODIFIED_FOLLOWING', '["USNY"]'),
('ECON_003', 'EQ_SWAP_003', '2024-03-10', '2024-09-10', 'MODIFIED_FOLLOWING', '["USNY"]');

-- =============================================================================
-- SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Example 1: Monthly Payment Schedule for Equity Swap
SELECT create_complete_schedule(
    'Monthly Payments - Trade 001',
    'PAYMENT',
    '2024-01-15',
    '2025-01-15',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS schedule_id_1;

-- Example 2: Quarterly Reset Schedule
SELECT create_complete_schedule(
    'Quarterly Resets - Trade 002',
    'RESET',
    '2024-02-01',
    '2024-08-01',
    'QUARTERLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'RESET',
    1
) AS schedule_id_2;

-- Example 3: Weekly Observation Schedule
SELECT create_complete_schedule(
    'Weekly Observations - Trade 003',
    'OBSERVATION',
    '2024-03-10',
    '2024-09-10',
    'WEEKLY',
    'FOLLOWING',
    'USNY',
    'OBSERVATION',
    1
) AS schedule_id_3;

-- Example 4: Semi-Annual Payment Schedule with Stub
SELECT create_complete_schedule(
    'Semi-Annual Payments with Stub',
    'PAYMENT',
    '2024-01-15',
    '2024-10-15',
    'SEMI_ANNUAL',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS schedule_id_4;

-- Example 5: Annual Schedule
SELECT create_complete_schedule(
    'Annual Settlement Schedule',
    'SETTLEMENT',
    '2024-01-01',
    '2026-12-31',
    'ANNUAL',
    'MODIFIED_FOLLOWING',
    'USNY',
    'SETTLEMENT',
    1
) AS schedule_id_5;

-- =============================================================================
-- MANUAL SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Manual schedule creation for more control
INSERT INTO ScheduleDefinition (
    schedule_id, schedule_name, schedule_type, 
    start_date, end_date, frequency, business_day_convention,
    first_regular_start_date, last_regular_end_date,
    start_stub_convention, end_stub_convention, roll_convention
) VALUES
('SCH_CUSTOM_001', 'Custom Monthly with Stubs', 'PAYMENT', 
 '2024-01-15', '2024-12-15', 'MONTHLY', 'MODIFIED_FOLLOWING',
 '2024-02-15', '2024-11-15', 'SHORT_INITIAL', 'SHORT_FINAL', 'EOM'),

('SCH_CUSTOM_002', 'Quarterly IMM Dates', 'RESET',
 '2024-03-20', '2024-12-18', 'QUARTERLY', 'MODIFIED_FOLLOWING',
 NULL, NULL, 'NONE', 'NONE', 'IMM'),

('SCH_CUSTOM_003', 'Complex Stub Schedule', 'OBSERVATION',
 '2024-01-10', '2024-07-10', 'MONTHLY', 'FOLLOWING',
 '2024-02-10', '2024-06-10', 'LONG_INITIAL', 'SHORT_FINAL', 'DAY_15');

-- Generate periods for custom schedules
INSERT INTO SchedulePeriod (
    period_id, schedule_id, start_date, end_date,
    adjusted_start_date, adjusted_end_date, period_type,
    period_number, total_periods, days_in_period
)
SELECT 
    'SCH_CUSTOM_001_P' || LPAD(row_number() OVER ()::TEXT, 3, '0'),
    'SCH_CUSTOM_001',
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    period_number,
    (SELECT COUNT(*) FROM generate_schedule('SCH_CUSTOM_001', '2024-01-15', '2024-12-15', 'MONTHLY')),
    days_in_period
FROM generate_schedule('SCH_CUSTOM_001', '2024-01-15', '2024-12-15', 'MONTHLY');

-- =============================================================================
-- BUSINESS CALENDAR EXTENSIONS
-- =============================================================================

-- Add more business centers
INSERT INTO BusinessCalendar (calendar_id, calendar_name, business_center_code, country_code, weekend_days) VALUES
('GBLO', 'London', 'GBLO', 'GB', '[1, 7]'),
('EUTA', 'Euro TARGET', 'EUTA', 'EU', '[1, 7]'),
('JPTO', 'Tokyo', 'JPTO', 'JP', '[1, 7]'),
('HKHK', 'Hong Kong', 'HKHK', 'HK', '[1, 7]'),
('SGSI', 'Singapore', 'SGSI', 'SG', '[1, 7]');

-- Add UK holidays
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
-- VALIDATION TESTS
-- =============================================================================

-- Test 1: Validate schedule generation
SELECT 
    schedule_id,
    schedule_name,
    start_date,
    end_date,
    frequency,
    total_periods,
    total_events
FROM schedule_overview
WHERE schedule_id IN (
    SELECT create_complete_schedule('Test Validation', 'PAYMENT', '2024-01-01', '2024-12-31', 'MONTHLY')
);

-- Test 2: Check business day adjustment
SELECT 
    original_date,
    convention,
    adjusted_date,
    calendar_id,
    is_business_day(adjusted_date, calendar_id) as is_business_day
FROM (
    SELECT 
        '2024-07-04'::DATE as original_date,
        'MODIFIED_FOLLOWING'::business_day_convention as convention,
        adjust_business_day('2024-07-04'::DATE, 'MODIFIED_FOLLOWING', 'USNY') as adjusted_date,
        'USNY' as calendar_id
) test_dates;

-- Test 3: Complex stub handling
SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    days_in_period
FROM schedule_details
WHERE schedule_id = 'SCH_CUSTOM_001'
ORDER BY period_number;

-- Test 4: Multi-calendar validation
SELECT 
    date_to_check,
    calendar_id,
    is_business_day(date_to_check, calendar_id) as is_business_day,
    CASE 
        WHEN is_business_day(date_to_check, calendar_id) THEN 'Business Day'
        ELSE 'Holiday/Weekend'
    END as status
FROM (
    SELECT 
        generate_series('2024-12-23'::DATE, '2024-12-31'::DATE, INTERVAL '1 day')::DATE as date_to_check,
        'USNY' as calendar_id
    UNION ALL
    SELECT 
        generate_series('2024-12-23'::DATE, '2024-12-31'::DATE, INTERVAL '1 day')::DATE,
        'GBLO'
) calendar_check;

-- =============================================================================
-- PERFORMANCE TESTS
-- =============================================================================

-- Test large schedule generation
SELECT create_complete_schedule(
    'Large Daily Schedule',
    'OBSERVATION',
    '2024-01-01',
    '2024-12-31',
    'DAILY',
    'FOLLOWING',
    'USNY',
    'OBSERVATION',
    1
) AS large_schedule_id;

-- Test quarterly over 5 years
SELECT create_complete_schedule(
    '5-Year Quarterly Schedule',
    'PAYMENT',
    '2020-01-01',
    '2025-01-01',
    'QUARTERLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS long_schedule_id;

-- =============================================================================
-- EDGE CASE TESTS
-- =============================================================================

-- Test: Single day schedule
SELECT create_complete_schedule(
    'Single Day Schedule',
    'TERMINAL',
    '2024-06-15',
    '2024-06-15',
    'TERMINAL',
    'NO_ADJUST',
    'USNY',
    'SETTLEMENT',
    1
) AS single_day_schedule;

-- Test: Weekend start/end
SELECT create_complete_schedule(
    'Weekend Schedule',
    'PAYMENT',
    '2024-06-15', -- Saturday
    '2024-06-30', -- Sunday
    'WEEKLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS weekend_schedule;

-- Test: Leap year handling
SELECT create_complete_schedule(
    'Leap Year Schedule',
    'MONTHLY',
    '2024-02-28',
    '2024-03-31',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS leap_year_schedule;

-- =============================================================================
-- VALIDATION SUMMARY
-- =============================================================================

-- Final validation of all created schedules
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
ORDER BY created_timestamp DESC
LIMIT 10;

SELECT 'Schedule Test Data Created Successfully' AS status;
