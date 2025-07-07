-- Rebalancing Monitoring and Control Queries
-- High-volume trading environment optimization
-- Microsoft SQL Server Implementation

-- =============================================================================
-- REBALANCING FREQUENCY MONITORING
-- =============================================================================

-- Query 1: Daily rebalancing activity summary
WITH DailyRebalancingStats AS (
    SELECT 
        CAST(event_timestamp AS DATE) as rebalancing_date,
        COUNT(*) as total_events,
        COUNT(CASE WHEN event_status = 'EXECUTED' THEN 1 END) as executed_events,
        COUNT(CASE WHEN event_type = 'THRESHOLD_BREACH' THEN 1 END) as threshold_breaches,
        COUNT(CASE WHEN event_type = 'SCHEDULED_REBALANCE' THEN 1 END) as scheduled_rebalances,
        AVG(estimated_rebalancing_cost) as avg_estimated_cost,
        AVG(actual_cost_incurred) as avg_actual_cost,
        AVG(estimated_market_impact_bps) as avg_estimated_impact,
        AVG(actual_market_impact_bps) as avg_actual_impact
    FROM RebalancingEvent
    WHERE event_timestamp >= DATEADD(day, -30, GETDATE())
    GROUP BY CAST(event_timestamp AS DATE)
),
TradingVolumeStats AS (
    SELECT 
        aggregation_date,
        SUM(total_trades_count) as daily_trades,
        SUM(total_notional_traded) as daily_notional,
        COUNT(CASE WHEN rebalancing_recommended = 1 THEN 1 END) as groups_needing_rebalancing
    FROM TradeAggregation
    WHERE aggregation_date >= DATEADD(day, -30, GETDATE())
    AND aggregation_period = 'DAILY'
    GROUP BY aggregation_date
)
SELECT 
    COALESCE(d.rebalancing_date, t.aggregation_date) as activity_date,
    COALESCE(d.total_events, 0) as rebalancing_events,
    COALESCE(d.executed_events, 0) as executed_rebalances,
    COALESCE(t.daily_trades, 0) as total_trades,
    COALESCE(t.daily_notional, 0) as total_notional,
    COALESCE(t.groups_needing_rebalancing, 0) as groups_needing_rebalancing,
    CASE WHEN t.daily_trades > 0 
         THEN CAST(COALESCE(d.executed_events, 0) AS DECIMAL(10,4)) / t.daily_trades * 100
         ELSE 0 END as rebalancing_to_trade_ratio_pct,
    COALESCE(d.avg_actual_cost, 0) as avg_rebalancing_cost,
    COALESCE(d.avg_actual_impact, 0) as avg_market_impact_bps
FROM DailyRebalancingStats d
FULL OUTER JOIN TradingVolumeStats t ON d.rebalancing_date = t.aggregation_date
ORDER BY activity_date DESC;

-- =============================================================================
-- THRESHOLD BREACH ANALYSIS
-- =============================================================================

-- Query 2: Current threshold status across all baskets
SELECT 
    tg.group_id,
    tg.group_name,
    rt.threshold_name,
    rt.threshold_type,
    rt.threshold_value,
    rt.threshold_unit,
    
    -- Current metrics (from latest aggregation)
    ta.largest_position_deviation_pct as current_weight_deviation,
    ta.tracking_error_contribution as current_tracking_error,
    ta.cash_flows_generated as current_cash_balance,
    
    -- Threshold comparison
    CASE rt.threshold_type
        WHEN 'WEIGHT_DEVIATION' THEN 
            CASE WHEN ta.largest_position_deviation_pct > rt.threshold_value THEN 'BREACH' ELSE 'OK' END
        WHEN 'TRACKING_ERROR' THEN 
            CASE WHEN ta.tracking_error_contribution * 10000 > rt.threshold_value THEN 'BREACH' ELSE 'OK' END
        WHEN 'CASH_BALANCE' THEN 
            CASE WHEN ABS(ta.cash_flows_generated) > rt.threshold_value THEN 'BREACH' ELSE 'OK' END
        ELSE 'UNKNOWN'
    END as threshold_status,
    
    -- Breach severity
    CASE rt.threshold_type
        WHEN 'WEIGHT_DEVIATION' THEN ta.largest_position_deviation_pct / rt.threshold_value
        WHEN 'TRACKING_ERROR' THEN (ta.tracking_error_contribution * 10000) / rt.threshold_value
        WHEN 'CASH_BALANCE' THEN ABS(ta.cash_flows_generated) / rt.threshold_value
        ELSE 0
    END as breach_severity_ratio,
    
    rt.breach_action,
    rt.last_breach_timestamp,
    rt.breach_count_30d,
    
    -- Recent rebalancing activity
    DATEDIFF(day, re.event_timestamp, GETDATE()) as days_since_last_rebalance
    
FROM TradeGroup tg
JOIN RebalancingThreshold rt ON tg.group_id = rt.group_id
LEFT JOIN (
    -- Get latest aggregation data
    SELECT DISTINCT group_id,
           FIRST_VALUE(largest_position_deviation_pct) OVER (PARTITION BY group_id ORDER BY aggregation_date DESC) as largest_position_deviation_pct,
           FIRST_VALUE(tracking_error_contribution) OVER (PARTITION BY group_id ORDER BY aggregation_date DESC) as tracking_error_contribution,
           FIRST_VALUE(cash_flows_generated) OVER (PARTITION BY group_id ORDER BY aggregation_date DESC) as cash_flows_generated
    FROM TradeAggregation
    WHERE aggregation_period = 'DAILY'
) ta ON tg.group_id = ta.group_id
LEFT JOIN (
    -- Get latest rebalancing event
    SELECT DISTINCT group_id,
           FIRST_VALUE(event_timestamp) OVER (PARTITION BY group_id ORDER BY event_timestamp DESC) as event_timestamp
    FROM RebalancingEvent
    WHERE event_status = 'EXECUTED'
) re ON tg.group_id = re.group_id
WHERE rt.threshold_status = 'ACTIVE'
ORDER BY breach_severity_ratio DESC, tg.group_id;

-- =============================================================================
-- REBALANCING EFFICIENCY ANALYSIS
-- =============================================================================

-- Query 3: Rebalancing efficiency and cost analysis
WITH RebalancingPerformance AS (
    SELECT 
        re.group_id,
        re.event_type,
        re.event_timestamp,
        re.estimated_rebalancing_cost,
        re.actual_cost_incurred,
        re.estimated_market_impact_bps,
        re.actual_market_impact_bps,
        
        -- Cost accuracy
        CASE WHEN re.estimated_rebalancing_cost > 0 
             THEN ABS(re.actual_cost_incurred - re.estimated_rebalancing_cost) / re.estimated_rebalancing_cost
             ELSE 0 END as cost_estimation_error_pct,
             
        -- Impact accuracy
        CASE WHEN re.estimated_market_impact_bps > 0 
             THEN ABS(re.actual_market_impact_bps - re.estimated_market_impact_bps) / re.estimated_market_impact_bps
             ELSE 0 END as impact_estimation_error_pct,
             
        -- Time to execution
        DATEDIFF(minute, re.event_timestamp, re.execution_start_time) as decision_to_execution_minutes,
        DATEDIFF(minute, re.execution_start_time, re.execution_end_time) as execution_duration_minutes,
        
        -- Workflow complexity
        rw.total_trades as rebalancing_trades_count,
        rw.risk_limits_breached,
        rw.execution_strategy
        
    FROM RebalancingEvent re
    LEFT JOIN RebalancingWorkflow rw ON re.workflow_id = rw.workflow_id
    WHERE re.event_status = 'EXECUTED'
    AND re.event_timestamp >= DATEADD(day, -90, GETDATE())
)
SELECT 
    rp.group_id,
    COUNT(*) as total_rebalancing_events,
    
    -- Cost performance
    AVG(rp.actual_cost_incurred) as avg_actual_cost,
    AVG(rp.cost_estimation_error_pct) * 100 as avg_cost_estimation_error_pct,
    STDEV(rp.cost_estimation_error_pct) * 100 as cost_estimation_volatility_pct,
    
    -- Market impact performance
    AVG(rp.actual_market_impact_bps) as avg_actual_market_impact_bps,
    AVG(rp.impact_estimation_error_pct) * 100 as avg_impact_estimation_error_pct,
    STDEV(rp.impact_estimation_error_pct) * 100 as impact_estimation_volatility_pct,
    
    -- Timing performance
    AVG(rp.decision_to_execution_minutes) as avg_decision_time_minutes,
    AVG(rp.execution_duration_minutes) as avg_execution_duration_minutes,
    
    -- Execution complexity
    AVG(CAST(rp.rebalancing_trades_count AS DECIMAL)) as avg_trades_per_rebalancing,
    COUNT(CASE WHEN rp.risk_limits_breached > 0 THEN 1 END) as events_with_risk_breaches,
    
    -- Efficiency score (lower cost and impact = higher efficiency)
    100 - (AVG(rp.actual_market_impact_bps) * 2 + AVG(rp.cost_estimation_error_pct) * 100) as efficiency_score,
    
    -- Recent trend (last 30 days vs previous 60 days)
    AVG(CASE WHEN rp.event_timestamp >= DATEADD(day, -30, GETDATE()) 
             THEN rp.actual_cost_incurred END) as recent_avg_cost,
    AVG(CASE WHEN rp.event_timestamp < DATEADD(day, -30, GETDATE()) 
             THEN rp.actual_cost_incurred END) as historical_avg_cost

FROM RebalancingPerformance rp
GROUP BY rp.group_id
HAVING COUNT(*) >= 3 -- Only show baskets with sufficient rebalancing history
ORDER BY efficiency_score DESC;

-- =============================================================================
-- OPERATIONAL DASHBOARD QUERIES
-- =============================================================================

-- Query 4: Real-time operational dashboard
SELECT 
    -- Current system status
    (SELECT COUNT(*) FROM TradeGroup WHERE group_status = 'ACTIVE') as active_baskets,
    (SELECT COUNT(*) FROM RebalancingEvent WHERE event_status = 'PENDING' 
     AND event_timestamp >= CAST(GETDATE() AS DATE)) as pending_rebalancing_events_today,
    (SELECT COUNT(*) FROM RebalancingWorkflow WHERE workflow_status = 'EXECUTING') as active_workflows,
    
    -- Today's activity
    (SELECT COUNT(*) FROM RebalancingEvent WHERE event_timestamp >= CAST(GETDATE() AS DATE)) as rebalancing_events_today,
    (SELECT SUM(total_trades_count) FROM TradeAggregation 
     WHERE aggregation_date = CAST(GETDATE() AS DATE) AND aggregation_period = 'DAILY') as total_trades_today,
    (SELECT COUNT(*) FROM TradeAggregation 
     WHERE aggregation_date = CAST(GETDATE() AS DATE) AND rebalancing_recommended = 1) as baskets_needing_attention,
    
    -- Risk alerts
    (SELECT COUNT(*) FROM RebalancingThreshold rt
     JOIN TradeAggregation ta ON rt.group_id = ta.group_id
     WHERE ta.aggregation_date = CAST(GETDATE() AS DATE)
     AND rt.threshold_type = 'WEIGHT_DEVIATION' 
     AND ta.largest_position_deviation_pct > rt.threshold_value) as weight_deviation_breaches,
     
    (SELECT COUNT(*) FROM RebalancingThreshold rt
     JOIN TradeAggregation ta ON rt.group_id = ta.group_id
     WHERE ta.aggregation_date = CAST(GETDATE() AS DATE)
     AND rt.threshold_type = 'TRACKING_ERROR' 
     AND ta.tracking_error_contribution * 10000 > rt.threshold_value) as tracking_error_breaches,
    
    -- System performance
    (SELECT AVG(DATEDIFF(minute, event_timestamp, COALESCE(execution_start_time, GETDATE())))
     FROM RebalancingEvent 
     WHERE event_timestamp >= DATEADD(day, -7, GETDATE())
     AND event_status IN ('APPROVED', 'EXECUTED')) as avg_approval_time_minutes_7d,
     
    (SELECT AVG(actual_market_impact_bps)
     FROM RebalancingEvent 
     WHERE event_timestamp >= DATEADD(day, -7, GETDATE())
     AND event_status = 'EXECUTED'
     AND actual_market_impact_bps IS NOT NULL) as avg_market_impact_bps_7d;

-- =============================================================================
-- BATCH OPTIMIZATION QUERIES
-- =============================================================================

-- Query 5: Identify optimal batching opportunities
WITH BatchingCandidates AS (
    SELECT 
        re.group_id,
        tg.group_name,
        re.event_type,
        re.scheduled_execution_time,
        re.estimated_rebalancing_cost,
        re.estimated_market_impact_bps,
        
        -- Grouping for potential batching
        DATEADD(hour, DATEDIFF(hour, 0, re.scheduled_execution_time), 0) as execution_hour_window,
        
        -- Complexity scoring for batching priority
        CASE re.event_type
            WHEN 'EMERGENCY_REBALANCE' THEN 1
            WHEN 'THRESHOLD_BREACH' THEN 2
            WHEN 'SCHEDULED_REBALANCE' THEN 3
            ELSE 4
        END as priority_score
        
    FROM RebalancingEvent re
    JOIN TradeGroup tg ON re.group_id = tg.group_id
    WHERE re.event_status = 'APPROVED'
    AND re.scheduled_execution_time <= DATEADD(day, 1, GETDATE())
    AND re.scheduled_execution_time >= GETDATE()
)
SELECT 
    bc.execution_hour_window,
    COUNT(*) as events_in_window,
    STRING_AGG(bc.group_name, ', ') as basket_names,
    MIN(bc.priority_score) as highest_priority,
    SUM(bc.estimated_rebalancing_cost) as total_estimated_cost,
    AVG(bc.estimated_market_impact_bps) as avg_estimated_impact,
    
    -- Batching recommendation
    CASE 
        WHEN COUNT(*) >= 3 AND MIN(bc.priority_score) >= 2 THEN 'RECOMMENDED'
        WHEN COUNT(*) >= 5 THEN 'STRONGLY_RECOMMENDED'
        WHEN MIN(bc.priority_score) = 1 THEN 'NOT_RECOMMENDED' -- Emergency events
        ELSE 'OPTIONAL'
    END as batching_recommendation,
    
    -- Estimated savings from batching
    SUM(bc.estimated_rebalancing_cost) * 0.15 as estimated_cost_savings, -- 15% typical batching savings
    AVG(bc.estimated_market_impact_bps) * 0.20 as estimated_impact_reduction -- 20% impact reduction

FROM BatchingCandidates bc
GROUP BY bc.execution_hour_window
HAVING COUNT(*) >= 2
ORDER BY COUNT(*) DESC, bc.execution_hour_window;
