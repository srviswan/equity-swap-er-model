-- =============================================================================
-- STANDALONE VALIDATION EXAMPLE
-- =============================================================================
-- This script demonstrates the validation query functionality
-- It can be run directly in SQL Server Management Studio or Azure Data Studio

-- First, ensure we have sample data for testing
-- This creates minimal test data to demonstrate the validation

-- Clean up any existing test data
IF OBJECT_ID('tempdb..#test_validation_data') IS NOT NULL
    DROP TABLE #test_validation_data;

-- Create sample test data
SELECT 
    'TRD001' as trade_id,
    'Test Trade 1' as trade_description,
    'PAYOUT001' as payout_id,
    1000000.00 as original_notional,
    0.05 as fixed_rate,
    0.0025 as spread,
    'ACT/360' as day_count_convention,
    1000.00 as scheduled_amount,
    1000.00 as expected_amount,
    'VALID' as validation_status
INTO #test_validation_data

UNION ALL

SELECT 
    'TRD002' as trade_id,
    'Test Trade 2' as trade_description,
    'PAYOUT002' as payout_id,
    2000000.00 as original_notional,
    0.045 as fixed_rate,
    0.0015 as spread,
    'ACT/360' as day_count_convention,
    1800.00 as scheduled_amount,
    1800.00 as expected_amount,
    'VALID' as validation_status

UNION ALL

SELECT 
    'TRD003' as trade_id,
    'Test Trade 3' as trade_description,
    'PAYOUT003' as payout_id,
    1500000.00 as original_notional,
    0.055 as fixed_rate,
    0.0030 as spread,
    'ACT/360' as day_count_convention,
    1600.00 as scheduled_amount,
    1595.83 as expected_amount,
    'INVALID' as validation_status;

-- Run the validation example
PRINT '=== VALIDATION EXAMPLE RESULTS ===';
PRINT '';

SELECT 
    trade_id,
    trade_description,
    payout_id,
    FORMAT(original_notional, 'N2') as original_notional,
    FORMAT(fixed_rate, 'P2') as fixed_rate,
    FORMAT(spread, 'P2') as spread,
    day_count_convention,
    COUNT(*) as total_flows,
    SUM(CASE WHEN validation_status = 'VALID' THEN 1 ELSE 0 END) as valid_flows,
    SUM(CASE WHEN validation_status = 'INVALID' THEN 1 ELSE 0 END) as invalid_flows,
    FORMAT(SUM(scheduled_amount), 'N2') as total_scheduled,
    FORMAT(SUM(expected_amount), 'N2') as total_expected,
    CASE 
        WHEN COUNT(*) = SUM(CASE WHEN validation_status = 'VALID' THEN 1 ELSE 0 END)
        THEN 'ALL_VALID'
        WHEN SUM(CASE WHEN validation_status = 'INVALID' THEN 1 ELSE 0 END) > 0
        THEN 'HAS_INVALID'
        ELSE 'PARTIAL'
    END as overall_validation
FROM #test_validation_data
GROUP BY trade_id, trade_description, payout_id, original_notional, fixed_rate, spread, day_count_convention
ORDER BY trade_id;

-- Additional example showing the calculation details
PRINT '';
PRINT '=== DETAILED CALCULATION BREAKDOWN ===';
PRINT '';

SELECT 
    trade_id,
    trade_description,
    FORMAT(original_notional, 'N2') as notional,
    FORMAT(fixed_rate, 'P2') as rate,
    FORMAT(spread, 'P2') as spread,
    FORMAT(scheduled_amount, 'N2') as scheduled,
    FORMAT(expected_amount, 'N2') as expected,
    FORMAT(ABS(scheduled_amount - expected_amount), 'N2') as difference,
    validation_status,
    CASE 
        WHEN validation_status = 'VALID' THEN 'Calculation matches expected'
        WHEN validation_status = 'INVALID' THEN 'Calculation differs from expected'
        ELSE 'Unknown status'
    END as status_description
FROM #test_validation_data
ORDER BY trade_id;

-- Clean up
DROP TABLE #test_validation_data;

PRINT '';
PRINT '=== EXAMPLE COMPLETED ===';
PRINT 'Run this script in SQL Server Management Studio to see the validation results';
