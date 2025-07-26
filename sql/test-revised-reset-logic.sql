-- =============================================================================
-- TEST SCRIPT: Revised Reset and Settlement Date Logic
-- =============================================================================
-- Tests the revised requirement for trade inclusion based on:
-- 1. Settlement date must be <= period end date
-- 2. Use cost notional before reset date
-- 3. Use post-reset notional from reset date onward
-- 
-- Test Scenario:
-- T1: Trade date July 1, Settlement date July 3
-- T2: Trade date July 15, Settlement date July 18  
-- T3: Trade date July 20, Settlement date July 23
-- Reset dates: July 18
-- =============================================================================

-- Clean up any existing test data
DELETE FROM equity_swap_time_series WHERE trade_id IN ('T1', 'T2', 'T3');
DELETE FROM Settlement WHERE trade_id IN ('T1', 'T2', 'T3');
DELETE FROM Trade WHERE trade_id IN ('T1', 'T2', 'T3');
DELETE FROM Payout WHERE product_id IN ('PROD1', 'PROD2', 'PROD3');
DELETE FROM InterestRatePayout WHERE payout_id IN ('PAYOUT1', 'PAYOUT2', 'PAYOUT3');

-- Set up test trades
INSERT INTO Trade (trade_id, product_id, trade_date, trade_status) VALUES
('T1', 'PROD1', '2024-07-01', 'CONFIRMED'),
('T2', 'PROD2', '2024-07-15', 'CONFIRMED'),
('T3', 'PROD3', '2024-07-20', 'CONFIRMED');

-- Set up payouts
INSERT INTO Payout (payout_id, product_id, payout_type) VALUES
('PAYOUT1', 'PROD1', 'INTEREST_RATE'),
('PAYOUT2', 'PROD2', 'INTEREST_RATE'),
('PAYOUT3', 'PROD3', 'INTEREST_RATE');

-- Set up interest rate payouts
INSERT INTO InterestRatePayout (payout_id, notional_amount, fixed_rate, day_count_convention) VALUES
('PAYOUT1', 1000000.00, 0.05, 'ACT/360'),
('PAYOUT2', 2000000.00, 0.045, 'ACT/360'),
('PAYOUT3', 1500000.00, 0.055, 'ACT/360');

-- Set up settlements
INSERT INTO Settlement (settlement_cycle_id, trade_id, settlement_date, settlement_status, settlement_amount) VALUES
('SET1', 'T1', '2024-07-03', 'SETTLED', 1000000.00),
('SET2', 'T2', '2024-07-18', 'SETTLED', 2000000.00),
('SET3', 'T3', '2024-07-23', 'SETTLED', 1500000.00);

-- Set up reset events (July 18 reset for all trades)
INSERT INTO equity_swap_time_series (
    trade_id, event_date, event_type, running_settled_quantity, 
    running_settled_notional, reset_price, event_description
) VALUES
-- T1 events
('T1', '2024-07-03', 'SETTLEMENT', 1000, 1000000.00, 1000.00, 'Initial settlement'),
('T1', '2024-07-18', 'RESET', 1000, 1050000.00, 1050.00, 'Post-reset notional update'),

-- T2 events
('T2', '2024-07-18', 'SETTLEMENT', 2000, 2000000.00, 1000.00, 'Initial settlement and reset'),

-- T3 events
('T3', '2024-07-23', 'SETTLEMENT', 1500, 1500000.00, 1000.00, 'Initial settlement');

-- =============================================================================
-- TEST 1: July 1 to July 30 (All trades should be included, all use post-reset)
-- =============================================================================
PRINT 'TEST 1: July 1 to July 30 - All trades included, post-reset notionals'
PRINT '=============================================================='

-- Test trade inclusion
SELECT 
    trade_id,
    trade_date,
    settlement_date,
    settlement_status,
    original_notional,
    current_post_reset_notional,
    latest_reset_date,
    include_in_calculation,
    effective_notional
FROM v_trade_interest_periods
WHERE trade_id IN ('T1', 'T2', 'T3')
ORDER BY trade_id;

-- Test individual trade calculations
EXEC sp_calculate_cdm_interest 'T1', '2024-07-01', '2024-07-30', 1;
EXEC sp_calculate_cdm_interest 'T2', '2024-07-01', '2024-07-30', 1;
EXEC sp_calculate_cdm_interest 'T3', '2024-07-01', '2024-07-30', 1;

-- =============================================================================
-- TEST 2: July 1 to July 15 (T1 and T2 should use cost notionals, T3 excluded)
-- =============================================================================
PRINT 'TEST 2: July 1 to July 15 - Cost notionals, T3 excluded'
PRINT '=============================================================='

-- Test trade inclusion
SELECT 
    trade_id,
    trade_date,
    settlement_date,
    settlement_status,
    original_notional,
    current_post_reset_notional,
    latest_reset_date,
    include_in_calculation,
    effective_notional
FROM v_trade_interest_periods
WHERE trade_id IN ('T1', 'T2', 'T3')
ORDER BY trade_id;

-- Test individual trade calculations
EXEC sp_calculate_cdm_interest 'T1', '2024-07-01', '2024-07-15', 1;
EXEC sp_calculate_cdm_interest 'T2', '2024-07-01', '2024-07-15', 1;
EXEC sp_calculate_cdm_interest 'T3', '2024-07-01', '2024-07-15', 1;

-- =============================================================================
-- TEST 3: July 1 to July 21 (T1 and T2 post-reset, T3 excluded)
-- =============================================================================
PRINT 'TEST 3: July 1 to July 21 - T1/T2 post-reset, T3 excluded'
PRINT '=============================================================='

-- Test trade inclusion
SELECT 
    trade_id,
    trade_date,
    settlement_date,
    settlement_status,
    original_notional,
    current_post_reset_notional,
    latest_reset_date,
    include_in_calculation,
    effective_notional
FROM v_trade_interest_periods
WHERE trade_id IN ('T1', 'T2', 'T3')
ORDER BY trade_id;

-- Test individual trade calculations
EXEC sp_calculate_cdm_interest 'T1', '2024-07-01', '2024-07-21', 1;
EXEC sp_calculate_cdm_interest 'T2', '2024-07-01', '2024-07-21', 1;
EXEC sp_calculate_cdm_interest 'T3', '2024-07-01', '2024-07-21', 1;

-- =============================================================================
-- VALIDATION SUMMARY
-- =============================================================================
PRINT 'VALIDATION SUMMARY'
PRINT '================='

-- Check trade inclusion logic
SELECT 
    'Trade Inclusion Test' as test_name,
    trade_id,
    settlement_date,
    CASE 
        WHEN settlement_date <= '2024-07-30' THEN 'Should be included'
        ELSE 'Should be excluded'
    END as expected_inclusion,
    CASE 
        WHEN include_in_calculation = 1 THEN 'Included'
        ELSE 'Excluded'
    END as actual_inclusion,
    CASE 
        WHEN (settlement_date <= '2024-07-30' AND include_in_calculation = 1) OR
             (settlement_date > '2024-07-30' AND include_in_calculation = 0) 
        THEN 'PASS' ELSE 'FAIL'
    END as test_result
FROM v_trade_interest_periods
WHERE trade_id IN ('T1', 'T2', 'T3');

-- Check reset date handling
SELECT 
    'Reset Handling Test' as test_name,
    trade_id,
    latest_reset_date,
    CASE 
        WHEN latest_reset_date IS NULL THEN 'Use cost notional'
        ELSE 'Use post-reset notional'
    END as expected_notional,
    effective_notional,
    CASE 
        WHEN latest_reset_date IS NULL AND effective_notional = original_notional THEN 'PASS'
        WHEN latest_reset_date IS NOT NULL AND effective_notional = current_post_reset_notional THEN 'PASS'
        ELSE 'FAIL'
    END as test_result
FROM v_trade_interest_periods
WHERE trade_id IN ('T1', 'T2', 'T3');

-- Clean up test data
-- DELETE FROM equity_swap_time_series WHERE trade_id IN ('T1', 'T2', 'T3');
-- DELETE FROM Settlement WHERE trade_id IN ('T1', 'T2', 'T3');
-- DELETE FROM Trade WHERE trade_id IN ('T1', 'T2', 'T3');
-- DELETE FROM Payout WHERE product_id IN ('PROD1', 'PROD2', 'PROD3');
-- DELETE FROM InterestRatePayout WHERE payout_id IN ('PAYOUT1', 'PAYOUT2', 'PAYOUT3');
