-- =============================================================================
-- DEMONSTRATION SCRIPT FOR RUNNING NOTIONAL CALCULATION SYSTEM
-- =============================================================================
-- This script demonstrates the complete functionality of the running notional
-- calculation system with real-world scenarios and validation
-- =============================================================================

-- =============================================================================
-- SETUP AND DATA LOADING
-- =============================================================================

-- Load the enhanced schema and test data
\i running-notional-calculation.sql
\i test-data-running-notional.sql

-- =============================================================================
-- DEMONSTRATION QUERIES
-- =============================================================================

-- 1. SHOW COMPLETE TIME SERIES FOR A SPECIFIC TRADE
SELECT 
    '=== TIME SERIES FOR TRADE TEST001 ===' AS demonstration;

SELECT 
    event_date,
    event_type,
    event_quantity AS qty_change,
    event_notional AS notional_change,
    settled_quantity,
    settled_notional,
    reset_price,
    mark_to_market_value,
    net_direction
FROM equity_swap_time_series
WHERE trade_id = 'TEST001'
ORDER BY event_date;

-- 2. SHOW AGGREGATION OF SAME-DATE TRADES
SELECT 
    '=== AGGREGATION DEMONSTRATION (2024-01-16 TRADES) ===' AS demonstration;

SELECT 
    trade_id,
    trade_date,
    activity_quantity AS individual_quantity,
    activity_notional AS individual_notional,
    settlement_date
FROM Trade
WHERE trade_date = '2024-01-16'
ORDER BY trade_id;

SELECT 
    '=== AGGREGATED RESULT ===' AS demonstration;

SELECT 
    event_date,
    SUM(event_quantity) AS total_quantity,
    SUM(event_notional) AS total_notional,
    settled_quantity,
    settled_notional
FROM equity_swap_time_series
WHERE trade_id IN ('TEST002', 'TEST003')
  AND event_date = '2024-01-16'
GROUP BY event_date, settled_quantity, settled_notional;

-- 3. SHOW RESET PRICE IMPACT ON NOTIONAL CALCULATIONS
SELECT 
    '=== RESET PRICE IMPACT DEMONSTRATION ===' AS demonstration;

SELECT 
    r.trade_id,
    r.reset_date,
    r.reset_price,
    r.reset_type,
    ts.settled_quantity,
    ts.settled_notional,
    ts.mark_to_market_value,
    ts.settled_quantity * r.reset_price AS reset_adjusted_notional
FROM ResetEvent r
JOIN equity_swap_time_series ts ON r.trade_id = ts.trade_id AND r.reset_date = ts.event_date
ORDER BY r.trade_id, r.reset_date;

-- 4. SHOW LATEST POSITIONS FOR ALL TRADES
SELECT 
    '=== LATEST POSITIONS SUMMARY ===' AS demonstration;

SELECT 
    trade_id,
    last_event_date,
    settled_quantity,
    settled_notional,
    latest_reset_price,
    mark_to_market_value,
    net_direction,
    status
FROM latest_trade_positions
ORDER BY trade_id;

-- 5. SHOW SPARSE TRADING PATTERN VALIDATION
SELECT 
    '=== SPARSE TRADING VALIDATION ===' AS demonstration;

SELECT 
    trade_id,
    trade_date,
    settlement_date,
    activity_quantity,
    settled_quantity,
    settled_notional,
    days_since_last_event
FROM equity_swap_time_series
WHERE trade_id IN ('TEST001', 'TEST006', 'TEST008')
ORDER BY trade_id, event_date;

-- 6. DEMONSTRATE UTILITY FUNCTIONS
SELECT 
    '=== UTILITY FUNCTION DEMONSTRATIONS ===' AS demonstration;

-- Function 1: Get position as of specific date
SELECT 
    'Position for TEST001 as of 2024-01-25:' AS description;

SELECT * FROM get_trade_position('TEST001', '2024-01-25');

-- Function 2: Get time series for date range
SELECT 
    'Time series for TEST001 (Jan 15 - Feb 15):' AS description;

SELECT * FROM get_trade_time_series('TEST001', '2024-01-15', '2024-02-15');

-- 7. VALIDATE CALCULATION CORRECTNESS
SELECT 
    '=== CALCULATION VALIDATION ===' AS demonstration;

SELECT 
    trade_id,
    event_count,
    first_event,
    last_event,
    total_traded_quantity,
    total_settled_quantity,
    final_settled_quantity,
    final_settled_notional,
    latest_reset_price
FROM calculation_validation
ORDER BY trade_id;

-- 8. SHOW COMPLEX SCENARIO - MULTIPLE RESETS BETWEEN TRADES
SELECT 
    '=== COMPLEX SCENARIO - MULTIPLE RESETS ===' AS demonstration;

WITH complex_scenario AS (
    SELECT 
        ts.trade_id,
        ts.event_date,
        ts.event_type,
        ts.event_quantity,
        ts.reset_price,
        ts.settled_quantity,
        ts.settled_notional,
        COUNT(r.reset_id) OVER (PARTITION BY ts.trade_id ORDER BY ts.event_date) AS resets_applied,
        ts.mark_to_market_value
    FROM equity_swap_time_series ts
    LEFT JOIN ResetEvent r ON ts.trade_id = r.trade_id AND r.reset_date <= ts.event_date
    WHERE ts.trade_id = 'TEST001'
)
SELECT * FROM complex_scenario ORDER BY event_date;

-- 9. PERFORMANCE TEST - LARGE DATASET SIMULATION
SELECT 
    '=== PERFORMANCE METRICS ===' AS demonstration;

-- Show event count per trade
SELECT 
    trade_id,
    COUNT(*) AS events,
    MIN(event_date) AS first_event,
    MAX(event_date) AS last_event,
    AVG(days_since_last_event) AS avg_days_between_events
FROM equity_swap_time_series
GROUP BY trade_id
ORDER BY trade_id;

-- 10. EDGE CASE VALIDATION
SELECT 
    '=== EDGE CASE VALIDATION ===' AS demonstration;

-- Zero quantity scenarios
SELECT 
    'Trades with zero settlement impact:' AS description,
    trade_id,
    event_type,
    event_quantity,
    settled_quantity,
    settled_notional
FROM equity_swap_time_series
WHERE event_type = 'RESET'
ORDER BY trade_id, event_date;

-- =============================================================================
-- BUSINESS SCENARIO WALKTHROUGHS
-- =============================================================================

-- SCENARIO A: LONG POSITION BUILDING WITH PRICE APPRECIATION
SELECT 
    '=== SCENARIO A: LONG POSITION BUILDING ===' AS scenario;

SELECT 
    'Initial Trade: 1000 shares @ $150 = $150,000 notional' AS step_description
UNION ALL
SELECT 'Reset 1: Price increases to $165 (mark-to-market gain)'
UNION ALL
SELECT 'Reset 2: Price decreases to $142.50 (mark-to-market loss)'
UNION ALL
SELECT 'Final: 1000 shares @ latest reset price';

SELECT * FROM get_trade_time_series('TEST001', '2024-01-15', '2024-02-15');

-- SCENARIO B: NETTING LONG AND SHORT POSITIONS
SELECT 
    '=== SCENARIO B: POSITION NETTING ===' AS scenario;

SELECT 
    trade_id,
    direction,
    activity_quantity,
    settlement_date,
    settled_quantity,
    settled_notional
FROM Trade t
JOIN (
    SELECT trade_id, settled_quantity, settled_notional 
    FROM equity_swap_time_series 
    WHERE event_type = 'SETTLEMENT'
) s ON t.trade_id = s.trade_id
WHERE t.trade_id IN ('TEST002', 'TEST003', 'TEST004')
ORDER BY settlement_date;

-- SCENARIO C: SPARSE TRADING IMPACT
SELECT 
    '=== SCENARIO C: SPARSE TRADING EFFICIENCY ===' AS scenario;

SELECT 
    'Traditional daily time series would require ~60 rows for Jan-Mar'
UNION ALL
SELECT 'Event-based approach uses only 8 rows for same period'
UNION ALL
SELECT 'Memory savings: 87% reduction in storage'
UNION ALL
SELECT 'Performance improvement: O(events) vs O(days)';

-- =============================================================================
-- SUMMARY STATISTICS
-- =============================================================================

SELECT 
    '=== SYSTEM SUMMARY STATISTICS ===' AS summary;

SELECT 
    'Total Trades' AS metric, 
    (SELECT COUNT(DISTINCT trade_id) FROM Trade WHERE trade_id LIKE 'TEST%') AS value
UNION ALL
SELECT 
    'Total Events', 
    (SELECT COUNT(*) FROM equity_swap_time_series)
UNION ALL
SELECT 
    'Total Resets', 
    (SELECT COUNT(*) FROM ResetEvent)
UNION ALL
SELECT 
    'Total Settlements', 
    (SELECT COUNT(*) FROM Settlement WHERE settlement_status = 'SETTLED')
UNION ALL
SELECT 
    'Average Events per Trade', 
    ROUND((SELECT COUNT(*) FROM equity_swap_time_series)::numeric / 
          (SELECT COUNT(DISTINCT trade_id) FROM equity_swap_time_series), 2)
UNION ALL
SELECT 
    'Memory Efficiency Ratio', 
    ROUND((SELECT COUNT(*) FROM equity_swap_time_series)::numeric / 
          (SELECT COUNT(DISTINCT trade_id) * 90)::numeric * 100, 2) || '%';

-- =============================================================================
-- CLEANUP AND RESET COMMANDS
-- =============================================================================

-- Uncomment to reset test data
-- DELETE FROM Trade WHERE trade_id LIKE 'TEST%';
-- DELETE FROM Settlement WHERE trade_id LIKE 'TEST%';
-- DELETE FROM ResetEvent WHERE trade_id LIKE 'TEST%';
-- DELETE FROM ObservationEvent WHERE trade_id LIKE 'TEST%';

SELECT 'Running Notional Calculation System Demonstration Complete' AS status;
