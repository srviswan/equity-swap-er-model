-- Query Examples for Independent Component Trade Management (MS SQL Server)
-- These queries demonstrate how to work with basket strategies executed as separate component trades
-- Converted from PostgreSQL to MS SQL Server syntax

-- 1. BASKET EXECUTION SUMMARY
-- View complete basket execution with all component details
SELECT 
    tg.group_id,
    tg.group_name,
    tg.group_type,
    tg.target_total_notional,
    tg.group_status,
    
    -- Execution timing (SQL Server uses DATEDIFF instead of EXTRACT)
    tg.execution_start_time,
    tg.execution_end_time,
    CASE 
        WHEN tg.execution_end_time IS NOT NULL AND tg.execution_start_time IS NOT NULL 
        THEN DATEDIFF(minute, tg.execution_start_time, tg.execution_end_time)
        ELSE NULL 
    END as execution_duration_minutes,
    
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
    tgm.trade_id,
    
    -- Target vs Actual
    tgm.target_weight,
    tgm.actual_weight,
    (tgm.actual_weight - tgm.target_weight) as weight_deviation,
    tgm.target_notional,
    tgm.actual_notional,
    (tgm.actual_notional - tgm.target_notional) as notional_deviation,
    
    -- Execution details
    es.execution_timestamp,
    es.execution_price,
    es.execution_venue,
    es.execution_algorithm,
    
    -- Performance metrics
    es.market_impact_bps,
    es.timing_alpha_bps,
    es.slippage_bps,
    
    tgm.fill_status,
    tgm.execution_priority
    
FROM TradeGroup tg
JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
LEFT JOIN ExecutionSequence es ON tgm.group_id = es.group_id AND tgm.trade_id = es.trade_id
WHERE tg.group_id = 'GRP_TECH_BASKET_001' -- Example group
ORDER BY tgm.execution_sequence;

-- 3. EXECUTION TIMELINE ANALYSIS
-- Track execution progress over time for basket strategies
WITH execution_timeline AS (
    SELECT 
        tg.group_id,
        tg.group_name,
        es.execution_timestamp,
        es.trade_id,
        tgm.execution_sequence,
        tgm.target_notional,
        tgm.actual_notional,
        
        -- Running totals
        SUM(tgm.actual_notional) OVER (
            PARTITION BY tg.group_id 
            ORDER BY es.execution_timestamp 
            ROWS UNBOUNDED PRECEDING
        ) as cumulative_notional,
        
        -- Calculate completion percentage
        SUM(tgm.actual_notional) OVER (
            PARTITION BY tg.group_id 
            ORDER BY es.execution_timestamp 
            ROWS UNBOUNDED PRECEDING
        ) / tg.target_total_notional * 100 as completion_percentage,
        
        -- Time between executions
        LAG(es.execution_timestamp) OVER (
            PARTITION BY tg.group_id 
            ORDER BY es.execution_timestamp
        ) as previous_execution_time
        
    FROM TradeGroup tg
    JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
    JOIN ExecutionSequence es ON tgm.group_id = es.group_id AND tgm.trade_id = es.trade_id
    WHERE tg.group_type = 'BASKET_STRATEGY'
)
SELECT 
    group_id,
    group_name,
    execution_timestamp,
    trade_id,
    execution_sequence,
    FORMAT(actual_notional, 'C', 'en-US') as execution_amount,
    FORMAT(cumulative_notional, 'C', 'en-US') as cumulative_amount,
    FORMAT(completion_percentage, 'N2') + '%' as completion_pct,
    CASE 
        WHEN previous_execution_time IS NOT NULL 
        THEN DATEDIFF(second, previous_execution_time, execution_timestamp)
        ELSE 0 
    END as seconds_since_previous
FROM execution_timeline
ORDER BY group_id, execution_timestamp;

-- 4. BASKET RECONSTITUTION TRACKING
-- Monitor basket building progress and composition accuracy
SELECT 
    br.reconstitution_id,
    tg.group_name,
    br.reconstitution_date,
    br.completion_percentage,
    br.tracking_error,
    br.total_deviation,
    br.remaining_trades,
    br.recon_status,
    
    -- Risk metrics
    br.portfolio_beta,
    br.portfolio_vega,
    br.concentration_risk,
    
    -- Timing estimates
    br.estimated_completion,
    CASE 
        WHEN br.estimated_completion IS NOT NULL 
        THEN DATEDIFF(hour, GETDATE(), br.estimated_completion)
        ELSE NULL 
    END as hours_to_completion,
    
    -- JSON composition analysis (basic string operations for SQL Server)
    LEN(br.target_composition) - LEN(REPLACE(br.target_composition, ',', '')) + 1 as target_components,
    CASE 
        WHEN br.current_composition IS NOT NULL 
        THEN LEN(br.current_composition) - LEN(REPLACE(br.current_composition, ',', '')) + 1
        ELSE 0 
    END as current_components
    
FROM BasketReconstitution br
JOIN TradeGroup tg ON br.group_id = tg.group_id
WHERE br.recon_status IN ('PLANNED', 'IN_PROGRESS')
ORDER BY br.reconstitution_date DESC, br.completion_percentage DESC;

-- 5. EXECUTION QUALITY ANALYSIS
-- Analyze execution performance across different components
WITH execution_quality AS (
    SELECT 
        tg.group_id,
        tg.group_name,
        COUNT(*) as total_executions,
        
        -- Market impact analysis
        AVG(es.market_impact_bps) as avg_market_impact_bps,
        MAX(es.market_impact_bps) as max_market_impact_bps,
        STDEV(es.market_impact_bps) as market_impact_volatility,
        
        -- Timing alpha analysis
        AVG(es.timing_alpha_bps) as avg_timing_alpha_bps,
        SUM(es.timing_alpha_bps) as total_timing_alpha_bps,
        
        -- Slippage analysis
        AVG(es.slippage_bps) as avg_slippage_bps,
        MAX(es.slippage_bps) as max_slippage_bps,
        
        -- Cost analysis
        SUM(es.execution_cost) as total_execution_cost,
        AVG(es.execution_cost) as avg_execution_cost,
        
        -- Venue analysis
        COUNT(DISTINCT es.execution_venue) as venues_used
        
    FROM TradeGroup tg
    JOIN ExecutionSequence es ON tg.group_id = es.group_id
    WHERE tg.group_type = 'BASKET_STRATEGY'
    GROUP BY tg.group_id, tg.group_name
)
SELECT 
    group_id,
    group_name,
    total_executions,
    venues_used,
    
    -- Performance metrics formatted
    FORMAT(avg_market_impact_bps, 'N2') + ' bps' as avg_market_impact,
    FORMAT(max_market_impact_bps, 'N2') + ' bps' as max_market_impact,
    FORMAT(avg_timing_alpha_bps, 'N2') + ' bps' as avg_timing_alpha,
    FORMAT(total_timing_alpha_bps, 'N2') + ' bps' as total_timing_alpha,
    FORMAT(avg_slippage_bps, 'N2') + ' bps' as avg_slippage,
    
    -- Cost metrics
    FORMAT(total_execution_cost, 'C', 'en-US') as total_cost,
    FORMAT(avg_execution_cost, 'C', 'en-US') as avg_cost_per_execution,
    
    -- Quality score (simple calculation)
    CASE 
        WHEN avg_market_impact_bps <= 5 AND avg_slippage_bps <= 3 THEN 'EXCELLENT'
        WHEN avg_market_impact_bps <= 10 AND avg_slippage_bps <= 5 THEN 'GOOD'
        WHEN avg_market_impact_bps <= 20 AND avg_slippage_bps <= 10 THEN 'ACCEPTABLE'
        ELSE 'POOR'
    END as execution_quality_rating
    
FROM execution_quality
ORDER BY total_timing_alpha_bps DESC;

-- 6. DEPENDENCY ANALYSIS
-- Analyze trade dependencies and execution order violations
SELECT 
    tgm.group_id,
    tg.group_name,
    tgm.trade_id,
    tgm.dependency_trade_id,
    tgm.execution_sequence,
    tgm.execution_priority,
    
    -- Dependency trade details
    dep_tgm.execution_sequence as dependency_sequence,
    dep_tgm.fill_status as dependency_status,
    
    -- Execution timing
    es.execution_timestamp as trade_execution_time,
    dep_es.execution_timestamp as dependency_execution_time,
    
    -- Validation
    CASE 
        WHEN tgm.dependency_trade_id IS NULL THEN 'NO_DEPENDENCY'
        WHEN dep_tgm.fill_status != 'FILLED' THEN 'DEPENDENCY_NOT_FILLED'
        WHEN es.execution_timestamp < dep_es.execution_timestamp THEN 'EXECUTION_ORDER_VIOLATION'
        ELSE 'DEPENDENCY_SATISFIED'
    END as dependency_check
    
FROM TradeGroupMember tgm
JOIN TradeGroup tg ON tgm.group_id = tg.group_id
LEFT JOIN TradeGroupMember dep_tgm ON tgm.dependency_trade_id = dep_tgm.trade_id
LEFT JOIN ExecutionSequence es ON tgm.group_id = es.group_id AND tgm.trade_id = es.trade_id
LEFT JOIN ExecutionSequence dep_es ON dep_tgm.group_id = dep_es.group_id AND dep_tgm.trade_id = dep_es.trade_id
WHERE tg.group_type = 'BASKET_STRATEGY'
ORDER BY tgm.group_id, tgm.execution_sequence;

-- 7. PARTIAL FILL ANALYSIS
-- Identify and analyze partially filled basket strategies
WITH partial_fill_analysis AS (
    SELECT 
        tg.group_id,
        tg.group_name,
        tg.target_total_notional,
        COUNT(*) as total_components,
        COUNT(CASE WHEN tgm.fill_status = 'FILLED' THEN 1 END) as filled_components,
        COUNT(CASE WHEN tgm.fill_status = 'PARTIAL' THEN 1 END) as partial_components,
        COUNT(CASE WHEN tgm.fill_status = 'PENDING' THEN 1 END) as pending_components,
        
        -- Notional analysis
        SUM(tgm.target_notional) as total_target,
        SUM(tgm.actual_notional) as total_filled,
        
        -- Calculate fill percentage
        SUM(tgm.actual_notional) / SUM(tgm.target_notional) * 100 as fill_percentage
        
    FROM TradeGroup tg
    JOIN TradeGroupMember tgm ON tg.group_id = tgm.group_id
    WHERE tg.group_type = 'BASKET_STRATEGY'
    GROUP BY tg.group_id, tg.group_name, tg.target_total_notional
)
SELECT 
    group_id,
    group_name,
    total_components,
    filled_components,
    partial_components,
    pending_components,
    
    -- Fill status summary
    FORMAT(fill_percentage, 'N2') + '%' as overall_fill_percentage,
    FORMAT(total_target, 'C', 'en-US') as target_notional,
    FORMAT(total_filled, 'C', 'en-US') as filled_notional,
    FORMAT(total_target - total_filled, 'C', 'en-US') as remaining_notional,
    
    -- Status classification
    CASE 
        WHEN fill_percentage >= 100 THEN 'COMPLETED'
        WHEN fill_percentage >= 90 THEN 'SUBSTANTIALLY_FILLED'
        WHEN fill_percentage >= 50 THEN 'PARTIALLY_FILLED'
        ELSE 'MINIMAL_FILL'
    END as fill_status_category
    
FROM partial_fill_analysis
WHERE fill_percentage < 100  -- Only show incomplete baskets
ORDER BY fill_percentage ASC;
