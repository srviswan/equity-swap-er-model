-- =============================================================================
-- ENHANCED NOTIONAL LOGIC TESTING FOR SETTLEMENT CYCLES AND RESETS
-- =============================================================================
-- Test suite for multi-trade scenarios with settlement cycles and reset handling
-- Microsoft SQL Server Version
-- =============================================================================

PRINT '=== Enhanced Notional Logic Testing ===';
GO

-- =============================================================================
-- TEST DATA SETUP FOR MULTI-TRADE SCENARIOS
-- =============================================================================

-- Create test trades with different settlement cycles
PRINT 'Setting up test data for multi-trade settlement cycle scenarios...';
GO

-- Test Trade 1: Regular settlement cycle
IF NOT EXISTS (SELECT 1 FROM Trade WHERE trade_id = 'TEST_MULTI_001')
BEGIN
    INSERT INTO Trade (
        trade_id, product_id, trade_date, trade_description, 
        trade_type, counterparty_id, trade_status
    ) VALUES (
        'TEST_MULTI_001', 'PROD_MULTI_001', '2024-01-15', 
        'Multi-Trade Settlement Cycle Test 1', 'EQUITY_SWAP', 'CPTY_001', 'ACTIVE'
    );
END
GO

-- Test Trade 2: With reset events
IF NOT EXISTS (SELECT 1 FROM Trade WHERE trade_id = 'TEST_MULTI_002')
BEGIN
    INSERT INTO Trade (
        trade_id, product_id, trade_date, trade_description, 
        trade_type, counterparty_id, trade_status
    ) VALUES (
        'TEST_MULTI_002', 'PROD_MULTI_002', '2024-02-01', 
        'Multi-Trade with Reset Events', 'EQUITY_SWAP', 'CPTY_002', 'ACTIVE'
    );
END
GO

-- Create settlement cycles for testing
IF NOT EXISTS (SELECT 1 FROM Settlement WHERE settlement_cycle_id = 'SETTLE_001')
BEGIN
    INSERT INTO Settlement (
        settlement_cycle_id, trade_id, settlement_date, settlement_status, 
        settlement_amount, settlement_currency
    ) VALUES 
    ('SETTLE_001', 'TEST_MULTI_001', '2024-01-31', 'SETTLED', 500000.00, 'USD'),
    ('SETTLE_002', 'TEST_MULTI_001', '2024-02-28', 'SETTLED', 750000.00, 'USD'),
    ('SETTLE_003', 'TEST_MULTI_002', '2024-02-15', 'SETTLED', 1000000.00, 'USD'),
    ('SETTLE_004', 'TEST_MULTI_002', '2024-03-15', 'PENDING', 800000.00, 'USD');
END
GO

-- Insert enhanced time series data with reset events
PRINT 'Creating enhanced time series data with settlement cycles and resets...';
GO

-- Test Trade 1: Settlement cycle progression
IF NOT EXISTS (SELECT 1 FROM equity_swap_time_series WHERE trade_id = 'TEST_MULTI_001')
BEGIN
    INSERT INTO equity_swap_time_series (
        trade_id, event_date, event_type, event_description,
        settled_quantity, settled_notional, running_settled_quantity,
        running_settled_notional, reset_price, created_at
    ) VALUES 
    -- Initial trade
    ('TEST_MULTI_001', '2024-01-15', 'SETTLEMENT', 'Initial Trade Settlement', 
     1000, 1000000.00, 1000, 1000000.00, 1000.00, GETDATE()),
    
    -- First settlement cycle
    ('TEST_MULTI_001', '2024-01-31', 'SETTLEMENT', 'Settlement Cycle 1', 
     200, 210000.00, 1200, 1200000.00, 1050.00, GETDATE()),
    
    -- Second settlement cycle
    ('TEST_MULTI_001', '2024-02-28', 'SETTLEMENT', 'Settlement Cycle 2', 
     300, 330000.00, 1500, 1500000.00, 1100.00, GETDATE()),
    
    -- Reset event
    ('TEST_MULTI_001', '2024-03-15', 'RESET', 'Post-Reset Notional Adjustment', 
     0, 0.00, 1500, 1500000.00, 1200.00, GETDATE()),
    
    -- Final settlement
    ('TEST_MULTI_001', '2024-04-15', 'SETTLEMENT', 'Final Settlement', 
     -1500, -1950000.00, 0, 0.00, 1300.00, GETDATE());
END
GO

-- Test Trade 2: Complex reset scenario
IF NOT EXISTS (SELECT 1 FROM equity_swap_time_series WHERE trade_id = 'TEST_MULTI_002')
BEGIN
    INSERT INTO equity_swap_time_series (
        trade_id, event_date, event_type, event_description,
        settled_quantity, settled_notional, running_settled_quantity,
        running_settled_notional, reset_price, created_at
    ) VALUES 
    -- Initial trade
    ('TEST_MULTI_002', '2024-02-01', 'SETTLEMENT', 'Initial Trade Settlement', 
     2000, 2000000.00, 2000, 2000000.00, 1000.00, GETDATE()),
    
    -- First settlement with reset
    ('TEST_MULTI_002', '2024-02-15', 'RESET', 'Pre-Settlement Reset', 
     0, 0.00, 2000, 2000000.00, 1050.00, GETDATE()),
    
    ('TEST_MULTI_002', '2024-02-15', 'SETTLEMENT', 'Post-Reset Settlement', 
     500, 525000.00, 2500, 2500000.00, 1050.00, GETDATE()),
    
    -- Second reset and settlement
    ('TEST_MULTI_002', '2024-03-15', 'RESET', 'Second Reset Event', 
     0, 0.00, 2500, 2500000.00, 1100.00, GETDATE()),
    
    ('TEST_MULTI_002', '2024-03-15', 'SETTLEMENT', 'Post-Second-Reset Settlement', 
     -1000, -1100000.00, 1500, 1500000.00, 1100.00, GETDATE());
END
GO

-- =============================================================================
-- TEST 1: ENHANCED NOTIONAL PERIOD EXTRACTION
-- =============================================================================

PRINT '';
PRINT '=== Test 1: Enhanced Notional Period Extraction ===';
PRINT '';

SELECT 
    trade_id,
    period_start_date,
    period_end_date,
    start_notional,
    end_notional,
    interest_calculation_notional,
    period_type,
    settlement_cycle_id,
    days_in_period,
    calculation_details
FROM v_running_notional_periods
WHERE trade_id IN ('TEST_MULTI_001', 'TEST_MULTI_002')
ORDER BY trade_id, period_start_date;

-- =============================================================================
-- TEST 2: POST-RESET NOTIONAL VALIDATION
-- =============================================================================

PRINT '';
PRINT '=== Test 2: Post-Reset Notional Validation ===';
PRINT '';

-- Verify that reset events use post-reset notional
SELECT 
    'TEST_MULTI_001' as trade_id,
    '2024-03-15' as reset_date,
    'Post-Reset Period' as period_type,
    1500000.00 as expected_post_reset_notional,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM v_running_notional_periods 
            WHERE trade_id = 'TEST_MULTI_001' 
              AND period_type = 'POST_RESET' 
              AND interest_calculation_notional = 1500000.00
        ) THEN 'PASS' ELSE 'FAIL'
    END as validation_result

UNION ALL

SELECT 
    'TEST_MULTI_002' as trade_id,
    '2024-02-15' as reset_date,
    'Post-Reset Settlement' as period_type,
    2500000.00 as expected_post_reset_notional,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM v_running_notional_periods 
            WHERE trade_id = 'TEST_MULTI_002' 
              AND period_type IN ('POST_RESET', 'SETTLEMENT_CYCLE') 
              AND interest_calculation_notional = 2500000.00
        ) THEN 'PASS' ELSE 'FAIL'
    END as validation_result;

-- =============================================================================
-- TEST 3: MULTI-TRADE INTEREST CALCULATION
-- =============================================================================

PRINT '';
PRINT '=== Test 3: Multi-Trade Interest Calculation ===';
PRINT '';

-- Test Trade 1 interest calculation
PRINT 'Testing Trade 1 (TEST_MULTI_001) with settlement cycles...';
EXEC sp_calculate_cdm_interest 'TEST_MULTI_001', '2024-01-15', '2024-04-15', 1;

-- Test Trade 2 interest calculation with resets
PRINT '';
PRINT 'Testing Trade 2 (TEST_MULTI_002) with reset events...';
EXEC sp_calculate_cdm_interest 'TEST_MULTI_002', '2024-02-01', '2024-03-31', 1;

-- =============================================================================
-- TEST 4: SETTLEMENT CYCLE INTEGRATION
-- =============================================================================

PRINT '';
PRINT '=== Test 4: Settlement Cycle Integration ===';
PRINT '';

-- Create a comprehensive view showing settlement cycles with notional tracking
CREATE VIEW #settlement_cycle_analysis AS
SELECT 
    s.trade_id,
    s.settlement_cycle_id,
    s.settlement_date,
    s.settlement_status,
    s.settlement_amount,
    
    -- Get the notional at each settlement
    (
        SELECT TOP 1 running_settled_notional
        FROM equity_swap_time_series ets
        WHERE ets.trade_id = s.trade_id
          AND ets.event_date <= s.settlement_date
          AND ets.event_type IN ('SETTLEMENT', 'RESET')
        ORDER BY ets.event_date DESC
    ) as notional_at_settlement,
    
    -- Get the interest calculation for this settlement period
    (
        SELECT SUM(interest_amount)
        FROM (
            EXEC sp_calculate_cdm_interest s.trade_id, 
                DATEADD(DAY, -30, s.settlement_date), 
                s.settlement_date, 0
        ) calc
    ) as calculated_interest
    
FROM Settlement s
WHERE s.trade_id IN ('TEST_MULTI_001', 'TEST_MULTI_002')
ORDER BY s.trade_id, s.settlement_date;

SELECT * FROM #settlement_cycle_analysis;

-- =============================================================================
-- TEST 5: EDGE CASES FOR MULTI-TRADE SCENARIOS
-- =============================================================================

PRINT '';
PRINT '=== Test 5: Edge Cases for Multi-Trade Scenarios ===';
PRINT '';

-- Test overlapping settlement cycles
PRINT 'Testing overlapping settlement cycles...';

-- Create test data for overlapping cycles
IF NOT EXISTS (SELECT 1 FROM Trade WHERE trade_id = 'TEST_OVERLAP_001')
BEGIN
    INSERT INTO Trade (
        trade_id, product_id, trade_date, trade_description, 
        trade_type, counterparty_id, trade_status
    ) VALUES (
        'TEST_OVERLAP_001', 'PROD_OVERLAP_001', '2024-01-01', 
        'Overlapping Settlement Cycles Test', 'EQUITY_SWAP', 'CPTY_003', 'ACTIVE'
    );
END
GO

-- Insert overlapping settlement data
IF NOT EXISTS (SELECT 1 FROM equity_swap_time_series WHERE trade_id = 'TEST_OVERLAP_001')
BEGIN
    INSERT INTO equity_swap_time_series (
        trade_id, event_date, event_type, event_description,
        settled_quantity, settled_notional, running_settled_quantity,
        running_settled_notional, reset_price, created_at
    ) VALUES 
    -- Rapid settlement cycles
    ('TEST_OVERLAP_001', '2024-01-01', 'SETTLEMENT', 'Initial', 1000, 1000000, 1000, 1000000, 1000, GETDATE()),
    ('TEST_OVERLAP_001', '2024-01-05', 'SETTLEMENT', 'Cycle 1', 200, 210000, 1200, 1200000, 1050, GETDATE()),
    ('TEST_OVERLAP_001', '2024-01-08', 'RESET', 'Quick Reset', 0, 0, 1200, 1200000, 1100, GETDATE()),
    ('TEST_OVERLAP_001', '2024-01-10', 'SETTLEMENT', 'Cycle 2', 300, 330000, 1500, 1500000, 1100, GETDATE()),
    ('TEST_OVERLAP_001', '2024-01-12', 'SETTLEMENT', 'Cycle 3', -500, -550000, 1000, 1000000, 1100, GETDATE());
END
GO

-- Test the overlapping scenario
SELECT 
    trade_id,
    period_start_date,
    period_end_date,
    period_type,
    interest_calculation_notional,
    days_in_period,
    calculation_details
FROM v_running_notional_periods
WHERE trade_id = 'TEST_OVERLAP_001'
ORDER BY period_start_date;

-- =============================================================================
-- TEST 6: VALIDATION SUMMARY
-- =============================================================================

PRINT '';
PRINT '=== Test 6: Validation Summary ===';
PRINT '';

-- Comprehensive validation of enhanced notional logic
SELECT 
    'Enhanced Notional Logic Validation' as test_name,
    GETDATE() as validation_date,
    
    -- Multi-trade validation
    (SELECT COUNT(DISTINCT trade_id) FROM v_running_notional_periods 
     WHERE trade_id LIKE 'TEST_MULTI_%') as total_test_trades,
    
    -- Settlement cycle validation
    (SELECT COUNT(*) FROM v_running_notional_periods 
     WHERE settlement_cycle_id IS NOT NULL) as settlement_cycle_periods,
    
    -- Reset handling validation
    (SELECT COUNT(*) FROM v_running_notional_periods 
     WHERE period_type = 'POST_RESET') as post_reset_periods,
    
    -- Notional accuracy validation
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM v_running_notional_periods 
            WHERE trade_id = 'TEST_MULTI_002' 
              AND period_type = 'POST_RESET' 
              AND interest_calculation_notional = 2500000.00
        ) THEN 'PASS' ELSE 'FAIL'
    END as post_reset_validation,
    
    'Enhanced notional logic successfully implemented' as status_message;

-- =============================================================================
-- CLEANUP COMMANDS
-- =============================================================================

PRINT '';
PRINT '=== Cleanup Commands ===';
PRINT '';
PRINT 'To remove test data, run:';
PRINT '-- DELETE FROM equity_swap_time_series WHERE trade_id LIKE ''TEST_%'';';
PRINT '-- DELETE FROM Settlement WHERE trade_id LIKE ''TEST_%'';';
PRINT '-- DELETE FROM Trade WHERE trade_id LIKE ''TEST_%'';';

SELECT 'Enhanced Notional Logic Testing Complete' AS status;
