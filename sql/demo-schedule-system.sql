-- =============================================================================
-- DEMONSTRATION SCRIPT FOR SCHEDULE CREATION SYSTEM
-- =============================================================================
-- This script demonstrates the complete schedule generation system
-- inspired by OpenGamma Strata PeriodicSchedule API
-- =============================================================================

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

-- Set search path and timezone
SET search_path TO public;
SET timezone TO 'America/New_York';

-- =============================================================================
-- BASIC SCHEDULE CREATION EXAMPLES
-- =============================================================================

-- Example 1: Create a simple monthly payment schedule
SELECT '=== EXAMPLE 1: Monthly Payment Schedule ===' AS example_description;

SELECT create_complete_schedule(
    'Equity Swap Monthly Payments',
    'PAYMENT',
    '2024-01-15',
    '2025-01-15',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS monthly_payment_schedule;

-- View the generated schedule
SELECT 
    schedule_id,
    schedule_name,
    schedule_type,
    start_date,
    end_date,
    frequency,
    total_periods,
    total_events
FROM schedule_overview 
WHERE schedule_name = 'Equity Swap Monthly Payments';

-- View detailed periods
SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    days_in_period
FROM schedule_details 
WHERE schedule_name = 'Equity Swap Monthly Payments'
ORDER BY period_number;

-- =============================================================================
-- ADVANCED SCHEDULE CREATION
-- =============================================================================

-- Example 2: Quarterly reset schedule with stubs
SELECT '=== EXAMPLE 2: Quarterly Reset Schedule with Stubs ===' AS example_description;

-- Manual creation for more control
INSERT INTO ScheduleDefinition (
    schedule_id, schedule_name, schedule_type, 
    start_date, end_date, frequency, business_day_convention,
    first_regular_start_date, last_regular_end_date,
    start_stub_convention, end_stub_convention, roll_convention
) VALUES 
('SCH_QUARTERLY_STUB', 'Quarterly Resets with Stubs', 'RESET', 
 '2024-02-01', '2024-11-01', 'QUARTERLY', 'MODIFIED_FOLLOWING',
 '2024-03-01', '2024-08-01', 'SHORT_INITIAL', 'SHORT_FINAL', 'EOM');

-- Generate periods
INSERT INTO SchedulePeriod (
    period_id, schedule_id, start_date, end_date,
    adjusted_start_date, adjusted_end_date, period_type,
    period_number, total_periods, days_in_period
)
SELECT 
    'SCH_QS_P' || LPAD(row_number() OVER ()::TEXT, 3, '0'),
    'SCH_QUARTERLY_STUB',
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    period_number,
    (SELECT COUNT(*) FROM generate_schedule('SCH_QUARTERLY_STUB', '2024-02-01', '2024-11-01', 'QUARTERLY')),
    days_in_period
FROM generate_schedule('SCH_QUARTERLY_STUB', '2024-02-01', '2024-11-01', 'QUARTERLY');

-- View the stub periods
SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    period_type,
    days_in_period,
    CASE 
        WHEN period_type = 'INITIAL_STUB' THEN 'First period is shorter'
        WHEN period_type = 'FINAL_STUB' THEN 'Last period is shorter'
        ELSE 'Regular quarterly period'
    END as description
FROM SchedulePeriod 
WHERE schedule_id = 'SCH_QUARTERLY_STUB'
ORDER BY period_number;

-- =============================================================================
-- BUSINESS DAY ADJUSTMENT DEMONSTRATION
-- =============================================================================

-- Example 3: Holiday and weekend adjustment
SELECT '=== EXAMPLE 3: Business Day Adjustments ===' AS example_description;

-- Create schedule that lands on holidays
SELECT create_complete_schedule(
    'Holiday Adjustment Demo',
    'PAYMENT',
    '2024-07-01',
    '2024-07-31',
    'WEEKLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS holiday_schedule;

-- Show adjustment details
SELECT 
    period_number,
    start_date,
    end_date,
    adjusted_start_date,
    adjusted_end_date,
    CASE 
        WHEN end_date != adjusted_end_date THEN 'Adjusted for holiday/weekend'
        ELSE 'No adjustment needed'
    END as adjustment_status
FROM schedule_details 
WHERE schedule_name = 'Holiday Adjustment Demo'
ORDER BY period_number;

-- =============================================================================
-- MULTI-CURRENCY/REGION SCHEDULES
-- =============================================================================

-- Example 4: London vs New York schedules
SELECT '=== EXAMPLE 4: Multi-Region Schedules ===' AS example_description;

-- London schedule
SELECT create_complete_schedule(
    'London Business Days',
    'PAYMENT',
    '2024-01-01',
    '2024-03-31',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'GBLO',
    'PAYMENT',
    1
) AS london_schedule;

-- New York schedule
SELECT create_complete_schedule(
    'New York Business Days',
    'PAYMENT',
    '2024-01-01',
    '2024-03-31',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS ny_schedule;

-- Compare the differences
SELECT 
    'London' as region,
    period_number,
    adjusted_end_date as payment_date
FROM schedule_details sd
JOIN ScheduleDefinition s ON sd.schedule_id = s.schedule_id
WHERE s.schedule_name = 'London Business Days'

UNION ALL

SELECT 
    'New York' as region,
    period_number,
    adjusted_end_date as payment_date
FROM schedule_details sd
JOIN ScheduleDefinition s ON sd.schedule_id = s.schedule_id
WHERE s.schedule_name = 'New York Business Days'

ORDER BY region, period_number;

-- =============================================================================
-- COMPLEX FINANCIAL INSTRUMENT SCHEDULES
-- =============================================================================

-- Example 5: Equity Swap with multiple legs
SELECT '=== EXAMPLE 5: Complex Equity Swap Schedule ===' AS example_description;

-- Floating leg reset schedule (quarterly)
SELECT create_complete_schedule(
    'Floating Leg Resets',
    'RESET',
    '2024-01-15',
    '2025-01-15',
    'QUARTERLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'RESET',
    1
) AS floating_resets;

-- Fixed leg payment schedule (semi-annual)
SELECT create_complete_schedule(
    'Fixed Leg Payments',
    'PAYMENT',
    '2024-01-15',
    '2025-01-15',
    'SEMI_ANNUAL',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS fixed_payments;

-- Equity observation schedule (daily)
SELECT create_complete_schedule(
    'Equity Price Observations',
    'OBSERVATION',
    '2024-01-15',
    '2024-01-22',
    'DAILY',
    'FOLLOWING',
    'USNY',
    'OBSERVATION',
    1
) AS equity_observations;

-- View all schedules for the equity swap
SELECT 
    s.schedule_name,
    s.schedule_type,
    s.frequency,
    COUNT(sp.period_id) as periods,
    MIN(sp.adjusted_start_date) as first_date,
    MAX(sp.adjusted_end_date) as last_date
FROM ScheduleDefinition s
JOIN SchedulePeriod sp ON s.schedule_id = sp.schedule_id
WHERE s.schedule_name LIKE '%Leg%' OR s.schedule_name LIKE '%Equity%'
GROUP BY s.schedule_id, s.schedule_name, s.schedule_type, s.frequency
ORDER BY first_date;

-- =============================================================================
-- VALIDATION AND ERROR HANDLING
-- =============================================================================

-- Example 6: Schedule validation
SELECT '=== EXAMPLE 6: Schedule Validation ===' AS example_description;

-- Create a potentially problematic schedule
SELECT create_complete_schedule(
    'Validation Test Schedule',
    'PAYMENT',
    '2024-01-31',
    '2024-02-28',
    'MONTHLY',
    'MODIFIED_FOLLOWING',
    'USNY',
    'PAYMENT',
    1
) AS validation_schedule;

-- Run validation
SELECT * FROM validate_schedule(
    (SELECT schedule_id FROM ScheduleDefinition WHERE schedule_name = 'Validation Test Schedule')
);

-- =============================================================================
-- PERFORMANCE ANALYSIS
-- =============================================================================

-- Example 7: Large schedule generation performance
SELECT '=== EXAMPLE 7: Performance Testing ===' AS example_description;

-- Generate a large daily schedule
SELECT create_complete_schedule(
    'Large Daily Schedule',
    'OBSERVATION',
    '2020-01-01',
    '2024-12-31',
    'DAILY',
    'FOLLOWING',
    'USNY',
    'OBSERVATION',
    1
) AS large_schedule;

-- Analyze the generated schedule
SELECT 
    schedule_name,
    start_date,
    end_date,
    frequency,
    total_periods,
    total_events,
    ROUND(total_periods::DECIMAL / (end_date - start_date) * 365, 2) as avg_days_per_period
FROM schedule_overview 
WHERE schedule_name = 'Large Daily Schedule';

-- =============================================================================
-- UTILITY QUERIES
-- =============================================================================

-- Find all schedules for a date range
SELECT 
    s.schedule_name,
    s.schedule_type,
    se.event_date,
    se.adjusted_event_date,
    se.event_type,
    se.status
FROM ScheduleDefinition s
JOIN ScheduleEvent se ON s.schedule_id = se.schedule_id
WHERE se.adjusted_event_date BETWEEN '2024-01-01' AND '2024-03-31'
ORDER BY se.adjusted_event_date, s.schedule_name;

-- Get schedules by type
SELECT 
    schedule_type,
    COUNT(*) as total_schedules,
    MIN(start_date) as earliest_start,
    MAX(end_date) as latest_end,
    AVG(end_date - start_date) as avg_duration_days
FROM ScheduleDefinition
GROUP BY schedule_type
ORDER BY total_schedules DESC;

-- Find overlapping schedules
SELECT 
    s1.schedule_name as schedule_1,
    s2.schedule_name as schedule_2,
    GREATEST(s1.start_date, s2.start_date) as overlap_start,
    LEAST(s1.end_date, s2.end_date) as overlap_end,
    LEAST(s1.end_date, s2.end_date) - GREATEST(s1.start_date, s2.start_date) as overlap_days
FROM ScheduleDefinition s1
JOIN ScheduleDefinition s2 ON s1.schedule_id < s2.schedule_id
WHERE s1.start_date <= s2.end_date AND s2.start_date <= s1.end_date
ORDER BY overlap_days DESC;

-- =============================================================================
-- CLEANUP AND RESET OPTIONS
-- =============================================================================

-- Optional: Clean up test data
-- DELETE FROM ScheduleEvent WHERE schedule_id LIKE 'SCH_TEST_%';
-- DELETE FROM SchedulePeriod WHERE schedule_id LIKE 'SCH_TEST_%';
-- DELETE FROM ScheduleDefinition WHERE schedule_name LIKE 'Test%';

SELECT 'Schedule System Demonstration Complete' AS status;
