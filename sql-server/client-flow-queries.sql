-- Client Flow Monitoring and Analysis Queries
-- Optimized for high-frequency client trading scenarios
-- Microsoft SQL Server Implementation

-- =============================================================================
-- CLIENT FLOW ACTIVITY MONITORING
-- =============================================================================

-- Query 1: Real-time client flow dashboard
WITH TodayFlows AS (
    SELECT 
        group_id,
        COUNT(CASE WHEN flow_type = 'SUBSCRIPTION' THEN 1 END) as subscriptions_count,
        COUNT(CASE WHEN flow_type = 'REDEMPTION' THEN 1 END) as redemptions_count,
        SUM(CASE WHEN flow_type = 'SUBSCRIPTION' THEN flow_notional ELSE 0 END) as total_subscriptions,
        SUM(CASE WHEN flow_type = 'REDEMPTION' THEN flow_notional ELSE 0 END) as total_redemptions,
        COUNT(DISTINCT client_id) as unique_clients,
        AVG(flow_price) as avg_flow_price,
        MIN(execution_timestamp) as first_trade_time,
        MAX(execution_timestamp) as last_trade_time
    FROM ClientFlowEvent
    WHERE CAST(execution_timestamp AS DATE) = CAST(GETDATE() AS DATE)
    GROUP BY group_id
),
CashPositions AS (
    SELECT 
        group_id,
        closing_cash_balance,
        client_subscriptions_cash,
        client_redemptions_cash,
        (closing_cash_balance - min_cash_threshold) as excess_cash,
        cash_utilization_pct
    FROM BasketCashManagement
    WHERE cash_balance_date = CAST(GETDATE() AS DATE)
)
SELECT 
    tg.group_name,
    tg.group_id,
    
    -- Flow activity
    ISNULL(tf.subscriptions_count, 0) as subscriptions_today,
    ISNULL(tf.redemptions_count, 0) as redemptions_today,
    ISNULL(tf.total_subscriptions, 0) as subscription_amount,
    ISNULL(tf.total_redemptions, 0) as redemption_amount,
    ISNULL(tf.total_subscriptions, 0) - ISNULL(tf.total_redemptions, 0) as net_flows_today,
    ISNULL(tf.unique_clients, 0) as active_clients_today,
    
    -- Flow intensity
    CASE WHEN DATEDIFF(hour, tf.first_trade_time, tf.last_trade_time) > 0
         THEN (tf.subscriptions_count + tf.redemptions_count) / 
              CAST(DATEDIFF(hour, tf.first_trade_time, tf.last_trade_time) AS DECIMAL(8,2))
         ELSE 0 END as trades_per_hour,
    
    -- Cash management
    ISNULL(cp.closing_cash_balance, 0) as current_cash_balance,
    ISNULL(cp.excess_cash, 0) as excess_cash,
    ISNULL(cp.cash_utilization_pct, 0) as cash_utilization_pct,
    
    -- Rebalancing indicators
    CASE WHEN cp.excess_cash > 2000000 THEN 'DEPLOY_CASH'
         WHEN ABS(ISNULL(tf.total_subscriptions, 0) - ISNULL(tf.total_redemptions, 0)) > 5000000 THEN 'HIGH_NET_FLOW'
         WHEN ISNULL(tf.subscriptions_count, 0) + ISNULL(tf.redemptions_count, 0) > 1000 THEN 'HIGH_ACTIVITY'
         ELSE 'NORMAL' END as rebalancing_signal,
    
    -- Trading metrics
    tf.avg_flow_price,
    DATEDIFF(minute, tf.first_trade_time, tf.last_trade_time) as trading_window_minutes

FROM TradeGroup tg
LEFT JOIN TodayFlows tf ON tg.group_id = tf.group_id
LEFT JOIN CashPositions cp ON tg.group_id = cp.group_id
WHERE tg.group_status = 'ACTIVE'
ORDER BY ABS(ISNULL(tf.total_subscriptions, 0) - ISNULL(tf.total_redemptions, 0)) DESC;

-- =============================================================================
-- CLIENT POSITION ANALYSIS
-- =============================================================================

-- Query 2: Top client positions and recent activity
WITH ClientActivity AS (
    SELECT 
        client_id,
        group_id,
        COUNT(*) as trades_30d,
        SUM(CASE WHEN flow_type = 'SUBSCRIPTION' THEN flow_notional ELSE 0 END) as subscriptions_30d,
        SUM(CASE WHEN flow_type = 'REDEMPTION' THEN flow_notional ELSE 0 END) as redemptions_30d,
        AVG(flow_price) as avg_price_30d,
        MAX(execution_timestamp) as last_trade_date
    FROM ClientFlowEvent
    WHERE execution_timestamp >= DATEADD(day, -30, GETDATE())
    GROUP BY client_id, group_id
)
SELECT 
    cbp.client_id,
    tg.group_name,
    
    -- Current position
    cbp.current_units,
    cbp.current_notional,
    cbp.entry_price,
    cbp.unrealized_pnl,
    
    -- Position ranking
    RANK() OVER (PARTITION BY cbp.group_id ORDER BY cbp.current_notional DESC) as position_rank,
    cbp.current_notional / SUM(cbp.current_notional) OVER (PARTITION BY cbp.group_id) * 100 as position_pct_of_basket,
    
    -- Recent activity
    ISNULL(ca.trades_30d, 0) as trades_last_30d,
    ISNULL(ca.subscriptions_30d, 0) as subscriptions_30d,
    ISNULL(ca.redemptions_30d, 0) as redemptions_30d,
    ISNULL(ca.subscriptions_30d, 0) - ISNULL(ca.redemptions_30d, 0) as net_flows_30d,
    
    -- Client classification
    CASE WHEN ca.trades_30d > 100 THEN 'HIGH_FREQUENCY'
         WHEN ca.trades_30d > 20 THEN 'ACTIVE'
         WHEN ca.trades_30d > 5 THEN 'MODERATE'
         WHEN ca.trades_30d > 0 THEN 'LOW'
         ELSE 'DORMANT' END as client_activity_level,
    
    -- Risk indicators
    CASE WHEN cbp.current_notional > 50000000 THEN 'LARGE_POSITION'
         WHEN ABS(ISNULL(ca.subscriptions_30d, 0) - ISNULL(ca.redemptions_30d, 0)) > 10000000 THEN 'HIGH_FLOW_IMPACT'
         ELSE 'NORMAL' END as risk_flag,
    
    ca.last_trade_date,
    DATEDIFF(day, ca.last_trade_date, GETDATE()) as days_since_last_trade

FROM ClientBasketPosition cbp
JOIN TradeGroup tg ON cbp.group_id = tg.group_id
LEFT JOIN ClientActivity ca ON cbp.client_id = ca.client_id AND cbp.group_id = ca.group_id
WHERE cbp.position_status = 'ACTIVE'
AND cbp.current_notional > 100000 -- Only show positions > $100K
ORDER BY cbp.group_id, cbp.current_notional DESC;

-- =============================================================================
-- FLOW PATTERN ANALYSIS
-- =============================================================================

-- Query 3: Flow patterns and rebalancing triggers
WITH HourlyFlowPattern AS (
    SELECT 
        group_id,
        DATEPART(hour, execution_timestamp) as trade_hour,
        COUNT(*) as trades_count,
        SUM(CASE WHEN flow_type = 'SUBSCRIPTION' THEN flow_notional ELSE 0 END) as hourly_subscriptions,
        SUM(CASE WHEN flow_type = 'REDEMPTION' THEN flow_notional ELSE 0 END) as hourly_redemptions,
        AVG(flow_impact_bps) as avg_impact_bps
    FROM ClientFlowEvent
    WHERE execution_timestamp >= DATEADD(day, -7, GETDATE())
    GROUP BY group_id, DATEPART(hour, execution_timestamp)
),
FlowTriggerStatus AS (
    SELECT 
        fbrt.group_id,
        fbrt.trigger_name,
        fbrt.trigger_type,
        fbrt.threshold_value,
        fbrt.threshold_unit,
        
        -- Current value vs threshold (simplified)
        CASE fbrt.trigger_type
            WHEN 'CASH_ACCUMULATION' THEN bcm.closing_cash_balance
            WHEN 'NET_FLOW_THRESHOLD' THEN ABS(bfa.net_flows)
            WHEN 'DRIFT_PERCENTAGE' THEN bfa.flow_driven_drift
            ELSE 0
        END as current_value,
        
        -- Breach status
        CASE 
            WHEN fbrt.trigger_type = 'CASH_ACCUMULATION' AND bcm.closing_cash_balance > fbrt.threshold_value THEN 'BREACHED'
            WHEN fbrt.trigger_type = 'NET_FLOW_THRESHOLD' AND ABS(bfa.net_flows) > fbrt.threshold_value THEN 'BREACHED'
            WHEN fbrt.trigger_type = 'DRIFT_PERCENTAGE' AND ABS(bfa.flow_driven_drift) > fbrt.threshold_value THEN 'BREACHED'
            ELSE 'OK'
        END as trigger_status,
        
        fbrt.auto_trigger_rebalancing,
        fbrt.rebalancing_urgency,
        fbrt.last_trigger_timestamp
        
    FROM FlowBasedRebalancingTrigger fbrt
    LEFT JOIN BasketCashManagement bcm ON fbrt.group_id = bcm.group_id 
        AND bcm.cash_balance_date = CAST(GETDATE() AS DATE)
    LEFT JOIN BasketFlowAggregation bfa ON fbrt.group_id = bfa.group_id 
        AND bfa.aggregation_date = CAST(GETDATE() AS DATE)
        AND bfa.aggregation_period = 'DAILY'
    WHERE fbrt.trigger_status = 'ACTIVE'
)
SELECT 
    tg.group_name,
    tg.group_id,
    
    -- Flow intensity patterns
    (SELECT AVG(CAST(trades_count AS DECIMAL)) FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id) as avg_trades_per_hour,
    (SELECT MAX(trades_count) FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id) as peak_hourly_trades,
    (SELECT STDEV(CAST(trades_count AS DECIMAL)) FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id) as trade_volatility,
    
    -- Peak trading hours
    (SELECT TOP 1 trade_hour FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id ORDER BY trades_count DESC) as peak_trading_hour,
    
    -- Flow balance patterns
    (SELECT AVG(hourly_subscriptions - hourly_redemptions) FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id) as avg_hourly_net_flow,
    (SELECT AVG(avg_impact_bps) FROM HourlyFlowPattern hp WHERE hp.group_id = tg.group_id) as avg_flow_impact_bps,
    
    -- Current trigger status
    STRING_AGG(fts.trigger_name + ': ' + fts.trigger_status, ', ') as trigger_summary,
    COUNT(CASE WHEN fts.trigger_status = 'BREACHED' THEN 1 END) as breached_triggers_count,
    COUNT(CASE WHEN fts.auto_trigger_rebalancing = 1 AND fts.trigger_status = 'BREACHED' THEN 1 END) as auto_rebalancing_triggers,
    
    -- Recommended actions
    CASE 
        WHEN COUNT(CASE WHEN fts.trigger_status = 'BREACHED' AND fts.rebalancing_urgency = 'URGENT' THEN 1 END) > 0 THEN 'IMMEDIATE_REBALANCING'
        WHEN COUNT(CASE WHEN fts.trigger_status = 'BREACHED' AND fts.auto_trigger_rebalancing = 1 THEN 1 END) > 0 THEN 'AUTO_REBALANCING'
        WHEN COUNT(CASE WHEN fts.trigger_status = 'BREACHED' THEN 1 END) > 0 THEN 'MANUAL_REVIEW'
        ELSE 'MONITOR'
    END as recommended_action

FROM TradeGroup tg
LEFT JOIN FlowTriggerStatus fts ON tg.group_id = fts.group_id
WHERE tg.group_status = 'ACTIVE'
GROUP BY tg.group_id, tg.group_name
ORDER BY breached_triggers_count DESC, tg.group_name;

-- =============================================================================
-- CASH DEPLOYMENT OPTIMIZATION
-- =============================================================================

-- Query 4: Cash deployment opportunities and efficiency
SELECT 
    tg.group_name,
    bcm.group_id,
    
    -- Current cash position
    bcm.closing_cash_balance,
    bcm.min_cash_threshold,
    bcm.max_cash_threshold,
    bcm.closing_cash_balance - bcm.min_cash_threshold as deployable_cash,
    
    -- Cash utilization
    bcm.cash_utilization_pct,
    CASE WHEN bcm.closing_cash_balance > bcm.max_cash_threshold THEN 'OVER_THRESHOLD'
         WHEN bcm.closing_cash_balance < bcm.min_cash_threshold THEN 'UNDER_THRESHOLD'
         ELSE 'NORMAL' END as cash_status,
    
    -- Flow patterns
    bcm.client_subscriptions_cash,
    bcm.client_redemptions_cash,
    bcm.client_subscriptions_cash - bcm.client_redemptions_cash as net_client_flows,
    
    -- Deployment metrics
    bcm.deployment_batch_size,
    FLOOR((bcm.closing_cash_balance - bcm.min_cash_threshold) / bcm.deployment_batch_size) as potential_deployment_batches,
    bcm.last_deployment_timestamp,
    DATEDIFF(hour, bcm.last_deployment_timestamp, GETDATE()) as hours_since_deployment,
    
    -- Recent flow trends (from aggregation)
    bfa.net_flows as today_net_flows,
    bfa.rebalancing_triggered as rebalancing_already_triggered,
    bfa.estimated_rebalancing_cost,
    
    -- Deployment recommendation
    CASE 
        WHEN bcm.closing_cash_balance > bcm.max_cash_threshold * 1.5 THEN 'URGENT_DEPLOYMENT'
        WHEN bcm.closing_cash_balance > bcm.max_cash_threshold THEN 'RECOMMENDED_DEPLOYMENT'
        WHEN bcm.auto_deployment_enabled = 1 AND bcm.closing_cash_balance > bcm.max_cash_threshold THEN 'AUTO_DEPLOYMENT'
        ELSE 'NO_ACTION'
    END as deployment_recommendation,
    
    -- Efficiency metrics
    bcm.closing_cash_balance / NULLIF(bcm.client_subscriptions_cash + bcm.client_redemptions_cash, 0) * 100 as cash_efficiency_ratio

FROM BasketCashManagement bcm
JOIN TradeGroup tg ON bcm.group_id = tg.group_id
LEFT JOIN BasketFlowAggregation bfa ON bcm.group_id = bfa.group_id 
    AND bfa.aggregation_date = bcm.cash_balance_date
    AND bfa.aggregation_period = 'DAILY'
WHERE bcm.cash_balance_date = CAST(GETDATE() AS DATE)
AND tg.group_status = 'ACTIVE'
ORDER BY (bcm.closing_cash_balance - bcm.min_cash_threshold) DESC;

-- =============================================================================
-- PERFORMANCE METRICS FOR HIGH-FREQUENCY TRADING
-- =============================================================================

-- Query 5: System performance metrics for high-volume client trading
WITH PerformanceMetrics AS (
    SELECT 
        group_id,
        CAST(execution_timestamp AS DATE) as trade_date,
        COUNT(*) as daily_trade_count,
        SUM(flow_notional) as daily_volume,
        AVG(flow_impact_bps) as avg_impact_bps,
        STDEV(flow_impact_bps) as impact_volatility,
        
        -- Timing analysis
        DATEDIFF(minute, MIN(execution_timestamp), MAX(execution_timestamp)) as trading_window_minutes,
        COUNT(DISTINCT client_id) as unique_clients,
        COUNT(*) / NULLIF(COUNT(DISTINCT client_id), 0) as trades_per_client,
        
        -- Flow balance
        SUM(CASE WHEN flow_type = 'SUBSCRIPTION' THEN flow_notional ELSE 0 END) as subscriptions,
        SUM(CASE WHEN flow_type = 'REDEMPTION' THEN flow_notional ELSE 0 END) as redemptions
        
    FROM ClientFlowEvent
    WHERE execution_timestamp >= DATEADD(day, -30, GETDATE())
    GROUP BY group_id, CAST(execution_timestamp AS DATE)
)
SELECT 
    tg.group_name,
    pm.group_id,
    
    -- Volume metrics
    AVG(pm.daily_trade_count) as avg_daily_trades,
    MAX(pm.daily_trade_count) as peak_daily_trades,
    AVG(pm.daily_volume) as avg_daily_volume,
    MAX(pm.daily_volume) as peak_daily_volume,
    
    -- Client engagement
    AVG(pm.unique_clients) as avg_daily_clients,
    AVG(pm.trades_per_client) as avg_trades_per_client,
    
    -- Market impact efficiency
    AVG(pm.avg_impact_bps) as avg_daily_impact_bps,
    AVG(pm.impact_volatility) as avg_impact_volatility,
    
    -- Flow characteristics
    AVG(pm.subscriptions - pm.redemptions) as avg_daily_net_flows,
    STDEV(pm.subscriptions - pm.redemptions) as net_flow_volatility,
    AVG(ABS(pm.subscriptions - pm.redemptions) / NULLIF(pm.subscriptions + pm.redemptions, 0)) * 100 as avg_flow_imbalance_pct,
    
    -- Operational efficiency
    AVG(pm.trading_window_minutes) as avg_trading_window_minutes,
    AVG(pm.daily_trade_count / NULLIF(pm.trading_window_minutes / 60.0, 0)) as avg_trades_per_hour,
    
    -- Recent trend (last 7 days vs previous 23 days)
    AVG(CASE WHEN pm.trade_date >= DATEADD(day, -7, GETDATE()) THEN pm.daily_trade_count END) as recent_avg_trades,
    AVG(CASE WHEN pm.trade_date < DATEADD(day, -7, GETDATE()) THEN pm.daily_trade_count END) as historical_avg_trades

FROM PerformanceMetrics pm
JOIN TradeGroup tg ON pm.group_id = tg.group_id
WHERE tg.group_status = 'ACTIVE'
GROUP BY tg.group_name, pm.group_id
HAVING COUNT(*) >= 10 -- Only show baskets with sufficient trading history
ORDER BY AVG(pm.daily_trade_count) DESC;
