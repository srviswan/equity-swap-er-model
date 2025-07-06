-- Query Examples for Independent Component Trade Management
-- These queries demonstrate how to work with basket strategies executed as separate component trades

-- 1. BASKET EXECUTION SUMMARY
-- View complete basket execution with all component details
SELECT 
    tg.group_id,
    tg.group_name,
    tg.group_type,
    tg.target_total_notional,
    tg.group_status,
    
    -- Execution timing
    tg.execution_start_time,
    tg.execution_end_time,
    EXTRACT(EPOCH FROM (tg.execution_end_time - tg.execution_start_time))/60 as execution_duration_minutes,
    
    -- Component count and status
    COUNT(tgm.trade_id) as total_components,
    COUNT(CASE WHEN tgm.fill_status = 'FILLED' THEN 1 END) as filled_components,
    
    -- Notional analysis
    SUM(tgm.target_notional) as total_target_notional,
    SUM(tgm.actual_notional) as total_actual_notional,
    (SUM(tgm.actual_notional) - SUM(tgm.target_notional)) as notional_deviation,
    
    -- Weight analysis
    SUM(ABS(tgm.actual_weight - tgm.target_weight)) as total_weight_deviation
    
FROM TradeGroup tg
LEFT JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
WHERE tg.group_type = 'BASKET_STRATEGY'
GROUP BY tg.group_id, tg.group_name, tg.group_type, tg.target_total_notional, 
         tg.group_status, tg.execution_start_time, tg.execution_end_time
ORDER BY tg.execution_start_time DESC;

-- 2. COMPONENT EXECUTION DETAILS
-- Detailed view of each component trade within basket strategies
SELECT 
    tg.group_name,
    tgm.execution_sequence,
    t.trade_id,
    u.asset_name,
    
    -- Target vs Actual
    tgm.target_weight,
    tgm.actual_weight,
    (tgm.actual_weight - tgm.target_weight) as weight_deviation,
    tgm.target_notional,
    tgm.actual_notional,
    (tgm.actual_notional - tgm.target_notional) as notional_deviation,
    
    -- Execution details
    es.execution_time,
    es.execution_price,
    es.execution_quantity,
    es.execution_venue,
    es.execution_algorithm,
    
    -- Performance metrics
    es.market_impact_bps,
    es.timing_alpha_bps,
    es.slippage_bps,
    
    tgm.fill_status
    
FROM TradeGroup tg
JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
JOIN Trade t ON tgm.trade_id = t.trade_id
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
LEFT JOIN ExecutionSequence es ON tgm.group_id = es.group_id AND tgm.trade_id = es.trade_id
WHERE tg.group_id = 'GRP001'
ORDER BY tgm.execution_sequence;

-- 3. EXECUTION TIMELINE ANALYSIS
-- Track execution sequence and timing for basket builds
SELECT 
    es.sequence_number,
    es.execution_time,
    t.trade_id,
    u.asset_name,
    es.execution_notional,
    
    -- Cumulative analysis
    SUM(es.execution_notional) OVER (
        PARTITION BY es.group_id 
        ORDER BY es.sequence_number 
        ROWS UNBOUNDED PRECEDING
    ) as cumulative_notional,
    
    -- Time gaps between executions
    LAG(es.execution_time) OVER (
        PARTITION BY es.group_id 
        ORDER BY es.sequence_number
    ) as previous_execution_time,
    
    EXTRACT(EPOCH FROM (
        es.execution_time - LAG(es.execution_time) OVER (
            PARTITION BY es.group_id 
            ORDER BY es.sequence_number
        )
    ))/60 as minutes_since_previous,
    
    -- Market impact analysis
    es.market_impact_bps,
    AVG(es.market_impact_bps) OVER (
        PARTITION BY es.group_id 
        ORDER BY es.sequence_number 
        ROWS UNBOUNDED PRECEDING
    ) as cumulative_avg_impact_bps
    
FROM ExecutionSequence es
JOIN Trade t ON es.trade_id = t.trade_id
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
WHERE es.group_id = 'GRP001'
ORDER BY es.sequence_number;

-- 4. BASKET RECONSTITUTION TRACKING
-- Monitor basket building progress and tracking error
SELECT 
    br.reconstitution_id,
    br.reconstitution_date,
    br.reconstitution_type,
    tg.group_name,
    
    -- Progress tracking
    br.completion_percentage,
    br.reconstitution_status,
    br.total_execution_time_minutes,
    
    -- Performance metrics
    br.tracking_error_bps,
    br.total_market_impact_bps,
    br.average_fill_ratio,
    
    -- Composition analysis
    br.target_composition,
    br.actual_composition,
    
    -- Individual component status
    COUNT(tgm.trade_id) as total_components,
    COUNT(CASE WHEN tgm.fill_status = 'FILLED' THEN 1 END) as filled_components,
    ROUND(
        COUNT(CASE WHEN tgm.fill_status = 'FILLED' THEN 1 END) * 100.0 / COUNT(tgm.trade_id), 
        2
    ) as fill_percentage
    
FROM BasketReconstitution br
JOIN TradeGroup tg ON br.group_id = tg.group_id
LEFT JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
GROUP BY br.reconstitution_id, br.reconstitution_date, br.reconstitution_type,
         tg.group_name, br.completion_percentage, br.reconstitution_status,
         br.total_execution_time_minutes, br.tracking_error_bps,
         br.total_market_impact_bps, br.average_fill_ratio,
         br.target_composition, br.actual_composition
ORDER BY br.reconstitution_date DESC;

-- 5. RISK AGGREGATION ACROSS COMPONENTS
-- Aggregate risk metrics from individual component trades to basket level
SELECT 
    tg.group_id,
    tg.group_name,
    
    -- Notional aggregation
    SUM(tgm.actual_notional) as total_basket_notional,
    
    -- Weight-adjusted risk aggregation
    SUM(v.market_value * tgm.actual_weight) as weighted_market_value,
    SUM(v.unrealized_pnl * tgm.actual_weight) as weighted_unrealized_pnl,
    SUM(v.delta * tgm.actual_weight) as weighted_delta,
    
    -- Execution performance
    AVG(es.market_impact_bps) as avg_market_impact_bps,
    AVG(es.slippage_bps) as avg_slippage_bps,
    SUM(es.timing_alpha_bps * tgm.actual_weight) as weighted_timing_alpha_bps,
    
    -- Component diversification
    COUNT(DISTINCT u.sector) as sector_count,
    COUNT(DISTINCT u.exchange) as exchange_count,
    
    -- Latest valuation date
    MAX(v.valuation_date) as latest_valuation_date
    
FROM TradeGroup tg
JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
JOIN Trade t ON tgm.trade_id = t.trade_id
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
LEFT JOIN Valuation v ON t.trade_id = v.trade_id
LEFT JOIN ExecutionSequence es ON tgm.group_id = es.group_id AND tgm.trade_id = es.trade_id
WHERE tg.group_type = 'BASKET_STRATEGY'
  AND tgm.fill_status = 'FILLED'
  AND (v.valuation_date IS NULL OR v.valuation_date = (
      SELECT MAX(v2.valuation_date) 
      FROM Valuation v2 
      WHERE v2.trade_id = t.trade_id
  ))
GROUP BY tg.group_id, tg.group_name
ORDER BY total_basket_notional DESC;

-- 6. FAILED/PARTIAL EXECUTION ANALYSIS
-- Identify and analyze incomplete basket executions
SELECT 
    tg.group_id,
    tg.group_name,
    tg.group_status,
    tg.target_total_notional,
    
    -- Execution completion
    COUNT(tgm.trade_id) as planned_components,
    COUNT(CASE WHEN tgm.fill_status = 'FILLED' THEN 1 END) as filled_components,
    COUNT(CASE WHEN tgm.fill_status = 'PARTIAL' THEN 1 END) as partial_components,
    COUNT(CASE WHEN tgm.fill_status = 'FAILED' THEN 1 END) as failed_components,
    
    -- Notional completion
    SUM(tgm.target_notional) as total_target_notional,
    SUM(COALESCE(tgm.actual_notional, 0)) as total_filled_notional,
    ROUND(
        SUM(COALESCE(tgm.actual_notional, 0)) * 100.0 / SUM(tgm.target_notional), 
        2
    ) as fill_percentage,
    
    -- Risk implications
    STRING_AGG(
        CASE WHEN tgm.fill_status != 'FILLED' 
        THEN u.asset_name || ' (' || tgm.fill_status || ')' 
        END, 
        ', '
    ) as unfilled_components,
    
    -- Time analysis
    tg.execution_start_time,
    COALESCE(tg.execution_end_time, CURRENT_TIMESTAMP) as end_or_current_time,
    EXTRACT(EPOCH FROM (
        COALESCE(tg.execution_end_time, CURRENT_TIMESTAMP) - tg.execution_start_time
    ))/60 as total_duration_minutes
    
FROM TradeGroup tg
JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
JOIN Trade t ON tgm.trade_id = t.trade_id
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
WHERE tg.group_type = 'BASKET_STRATEGY'
  AND tg.group_status != 'COMPLETED'
GROUP BY tg.group_id, tg.group_name, tg.group_status, tg.target_total_notional,
         tg.execution_start_time, tg.execution_end_time
HAVING COUNT(CASE WHEN tgm.fill_status != 'FILLED' THEN 1 END) > 0
ORDER BY tg.execution_start_time DESC;
