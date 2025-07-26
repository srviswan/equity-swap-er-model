-- =============================================================================
-- SPREAD OVERRIDE TEST SUITE
-- =============================================================================
-- Test script to validate dynamic spread override functionality
-- Tests long/short spread overrides on any date within calculation periods
-- =============================================================================

USE [equity_swap_db];
GO

-- =============================================================================
-- SETUP TEST DATA
-- =============================================================================

-- Create test trades with spread override events
DELETE FROM equity_swap_time_series WHERE trade_id LIKE 'TEST_SPREAD_%';
DELETE FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%';
DELETE FROM Payout WHERE product_id IN (SELECT product_id FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%');
DELETE FROM InterestRatePayout WHERE payout_id IN (SELECT payout_id FROM Payout WHERE product_id IN (SELECT product_id FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%'));

-- Test Trade 1: Basic spread override
INSERT INTO Trade (trade_id, product_id, trade_date, trade_description, trade_status, currency, notional_amount, fixed_rate, day_count_convention, settlement_date, settlement_status)
VALUES 
('TEST_SPREAD_001', 'PROD_001', '2024-01-01', 'Test Spread Override Trade 1', 'ACTIVE', 'USD', 1000000.00, 0.05, 'ACT_360', '2024-01-05', 'SETTLED');

INSERT INTO Payout (payout_id, product_id, payout_type, payout_status, payout_currency, payout_amount)
VALUES 
('PAYOUT_001', 'PROD_001', 'INTEREST', 'ACTIVE', 'USD', 0.00);

INSERT INTO InterestRatePayout (payout_id, notional_amount, notional_currency, rate_type, fixed_rate, floating_rate_index, spread, day_count_convention, compounding_frequency, payment_frequency)
VALUES 
('PAYOUT_001', 1000000.00, 'USD', 'FIXED', 0.05, NULL, 0.0025, 'ACT_360', 'NONE', 'QUARTERLY');

-- Test Trade 2: Multiple spread overrides
INSERT INTO Trade (trade_id, product_id, trade_date, trade_description, trade_status, currency, notional_amount, fixed_rate, day_count_convention, settlement_date, settlement_status)
VALUES 
('TEST_SPREAD_002', 'PROD_002', '2024-01-01', 'Test Multiple Spread Overrides', 'ACTIVE', 'USD', 2000000.00, 0.045, 'ACT_360', '2024-01-05', 'SETTLED');

INSERT INTO Payout (payout_id, product_id, payout_type, payout_status, payout_currency, payout_amount)
VALUES 
('PAYOUT_002', 'PROD_002', 'INTEREST', 'ACTIVE', 'USD', 0.00);

INSERT INTO InterestRatePayout (payout_id, notional_amount, notional_currency, rate_type, fixed_rate, floating_rate_index, spread, day_count_convention, compounding_frequency, payment_frequency)
VALUES 
('PAYOUT_002', 2000000.00, 'USD', 'FIXED', 0.045, NULL, 0.0030, 'ACT_360', 'NONE', 'QUARTERLY');

-- Test Trade 3: Long/Short spread differentiation
INSERT INTO Trade (trade_id, product_id, trade_date, trade_description, trade_status, currency, notional_amount, fixed_rate, day_count_convention, settlement_date, settlement_status)
VALUES 
('TEST_SPREAD_003', 'PROD_003', '2024-01-01', 'Test Long/Short Spreads', 'ACTIVE', 'USD', 1500000.00, 0.055, 'ACT_360', '2024-01-05', 'SETTLED');

INSERT INTO Payout (payout_id, product_id, payout_type, payout_status, payout_currency, payout_amount)
VALUES 
('PAYOUT_003', 'PROD_003', 'INTEREST', 'ACTIVE', 'USD', 0.00);

INSERT INTO InterestRatePayout (payout_id, notional_amount, notional_currency, rate_type, fixed_rate, floating_rate_index, spread, day_count_convention, compounding_frequency, payment_frequency)
VALUES 
('PAYOUT_003', 1500000.00, 'USD', 'FIXED', 0.055, NULL, 0.0020, 'ACT_360', 'NONE', 'QUARTERLY');

-- =============================================================================
-- INSERT SPREAD OVERRIDE EVENTS
-- =============================================================================

-- Test 1: Single spread override mid-period
INSERT INTO equity_swap_time_series (trade_id, event_date, event_type, running_settled_notional, reset_price, long_spread, short_spread, override_type)
VALUES 
('TEST_SPREAD_001', '2024-02-15', 'SPREAD_OVERRIDE', NULL, NULL, 0.0035, 0.0020, 'MANUAL_OVERRIDE');

-- Test 2: Multiple spread overrides
INSERT INTO equity_swap_time_series (trade_id, event_date, event_type, running_settled_notional, reset_price, long_spread, short_spread, override_type)
VALUES 
('TEST_SPREAD_002', '2024-02-01', 'SPREAD_OVERRIDE', NULL, NULL, 0.0040, 0.0025, 'MANUAL_OVERRIDE'),
('TEST_SPREAD_002', '2024-03-15', 'SPREAD_OVERRIDE', NULL, NULL, 0.0030, 0.0015, 'MANUAL_OVERRIDE'),
('TEST_SPREAD_002', '2024-04-01', 'SPREAD_OVERRIDE', NULL, NULL, 0.0050, 0.0030, 'MANUAL_OVERRIDE');

-- Test 3: Long/Short spread differentiation
INSERT INTO equity_swap_time_series (trade_id, event_date, event_type, running_settled_notional, reset_price, long_spread, short_spread, override_type)
VALUES 
('TEST_SPREAD_003', '2024-01-15', 'SPREAD_OVERRIDE', NULL, NULL, 0.0030, 0.0010, 'MANUAL_OVERRIDE'),
('TEST_SPREAD_003', '2024-02-15', 'SPREAD_OVERRIDE', NULL, NULL, 0.0040, 0.0015, 'MANUAL_OVERRIDE'),
('TEST_SPREAD_003', '2024-03-15', 'SPREAD_OVERRIDE', NULL, NULL, 0.0025, 0.0005, 'MANUAL_OVERRIDE');

-- Add reset events for notional changes
INSERT INTO equity_swap_time_series (trade_id, event_date, event_type, running_settled_notional, reset_price)
VALUES 
('TEST_SPREAD_001', '2024-01-15', 'RESET', 1050000.00, 105.00),
('TEST_SPREAD_002', '2024-02-01', 'RESET', 2100000.00, 105.00),
('TEST_SPREAD_003', '2024-03-01', 'RESET', 1575000.00, 105.00);

-- =============================================================================
-- TEST CASES
-- =============================================================================

PRINT '=== TEST CASE 1: Single Spread Override ===';
PRINT 'Calculation Period: 2024-01-01 to 2024-03-31';
PRINT 'Expected: Spread changes from 0.0025 to 0.0035 on 2024-02-15';
PRINT '';

EXEC sp_calculate_cdm_interest 'TEST_SPREAD_001', '2024-01-01', '2024-03-31', 1;

PRINT '=== TEST CASE 2: Multiple Spread Overrides ===';
PRINT 'Calculation Period: 2024-01-01 to 2024-06-30';
PRINT 'Expected: Spread changes at 2024-02-01, 2024-03-15, 2024-04-01';
PRINT '';

EXEC sp_calculate_cdm_interest 'TEST_SPREAD_002', '2024-01-01', '2024-06-30', 1;

PRINT '=== TEST CASE 3: Long/Short Spread Differentiation ===';
PRINT 'Calculation Period: 2024-01-01 to 2024-06-30';
PRINT 'Expected: Long spreads: 0.0020->0.0030->0.0040->0.0025';
PRINT 'Expected: Short spreads: 0.0020->0.0010->0.0015->0.0005';
PRINT '';

EXEC sp_calculate_cdm_interest 'TEST_SPREAD_003', '2024-01-01', '2024-06-30', 1;

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Verify spread override events
SELECT 
    trade_id,
    event_date,
    event_type,
    long_spread,
    short_spread,
    override_type
FROM equity_swap_time_series
WHERE trade_id LIKE 'TEST_SPREAD_%'
    AND event_type = 'SPREAD_OVERRIDE'
ORDER BY trade_id, event_date;

-- Calculate expected vs actual interest with spread overrides
WITH expected_calculations AS (
    SELECT 
        'TEST_SPREAD_001' as trade_id,
        '2024-01-01' as period_start,
        '2024-02-15' as period_end,
        1000000.00 as notional,
        0.0525 as total_rate, -- 0.05 + 0.0025
        DATEDIFF(DAY, '2024-01-01', '2024-02-15') as days,
        45 as days_in_year,
        ROUND(1000000.00 * 0.0525 * 45.0/360.0, 2) as expected_interest
    
    UNION ALL
    
    SELECT 
        'TEST_SPREAD_001',
        '2024-02-15',
        '2024-03-31',
        1000000.00,
        0.0535, -- 0.05 + 0.0035
        DATEDIFF(DAY, '2024-02-15', '2024-03-31'),
        45,
        ROUND(1000000.00 * 0.0535 * 44.0/360.0, 2)
),
actual_calculations AS (
    SELECT 
        trade_id,
        SUM(interest_amount) as actual_interest,
        COUNT(*) as period_count
    FROM #cdm_interest_calculations
    WHERE trade_id = 'TEST_SPREAD_001'
    GROUP BY trade_id
)
SELECT 
    e.trade_id,
    SUM(e.expected_interest) as total_expected,
    a.actual_interest as total_actual,
    CASE 
        WHEN ABS(SUM(e.expected_interest) - a.actual_interest) < 0.01 THEN 'PASS'
        ELSE 'FAIL'
    END as test_result
FROM expected_calculations e
JOIN actual_calculations a ON e.trade_id = a.trade_id
GROUP BY e.trade_id, a.actual_interest;

-- =============================================================================
-- CLEANUP
-- =============================================================================

-- Optional cleanup after testing
-- DELETE FROM equity_swap_time_series WHERE trade_id LIKE 'TEST_SPREAD_%';
-- DELETE FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%';
-- DELETE FROM Payout WHERE product_id IN (SELECT product_id FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%');
-- DELETE FROM InterestRatePayout WHERE payout_id IN (SELECT payout_id FROM Payout WHERE product_id IN (SELECT product_id FROM Trade WHERE trade_id LIKE 'TEST_SPREAD_%'));

PRINT '=== SPREAD OVERRIDE TESTS COMPLETED ===';
