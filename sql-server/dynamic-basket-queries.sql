-- Dynamic Basket Management Queries
-- Comprehensive query examples for managing dynamic underlier additions
-- Microsoft SQL Server Implementation

-- =============================================================================
-- QUERY 1: CURRENT BASKET COMPOSITION WITH PENDING CHANGES
-- =============================================================================

-- Shows current active composition and any pending dynamic changes
WITH CurrentBasketState AS (
    SELECT 
        tg.group_id,
        tg.group_name,
        tg.group_status,
        tg.target_total_notional,
        
        -- Get current active version
        bcv_current.version_id as current_version_id,
        bcv_current.version_number as current_version,
        bcv_current.target_composition as current_composition,
        bcv_current.activated_timestamp as current_since,
        
        -- Check for pending changes
        bcv_pending.version_id as pending_version_id,
        bcv_pending.version_number as pending_version,
        bcv_pending.target_composition as pending_composition,
        bcv_pending.version_type as pending_change_type,
        bcv_pending.change_reason as pending_reason,
        
        -- Count of pending additions
        (SELECT COUNT(*) 
         FROM DynamicUnderlierAddition dua 
         WHERE dua.group_id = tg.group_id 
         AND dua.addition_status IN ('REQUESTED', 'UNDER_REVIEW', 'APPROVED')) as pending_additions,
        
        -- Active rebalancing workflows
        (SELECT COUNT(*) 
         FROM RebalancingWorkflow rw 
         WHERE rw.group_id = tg.group_id 
         AND rw.workflow_status IN ('PLANNED', 'APPROVED', 'EXECUTING')) as active_workflows
        
    FROM TradeGroup tg
    LEFT JOIN BasketCompositionVersion bcv_current ON tg.group_id = bcv_current.group_id 
        AND bcv_current.version_status = 'ACTIVE'
    LEFT JOIN BasketCompositionVersion bcv_pending ON tg.group_id = bcv_pending.group_id 
        AND bcv_pending.version_status = 'PENDING'
    WHERE tg.group_type = 'BASKET_STRATEGY'
)
SELECT 
    group_id,
    group_name,
    group_status,
    FORMAT(target_total_notional, 'C') as target_notional,
    current_version,
    current_composition,
    current_since,
    
    -- Pending changes summary
    CASE 
        WHEN pending_version IS NOT NULL THEN 
            CONCAT('Version ', pending_version, ' (', pending_change_type, ') - ', pending_reason)
        ELSE 'No pending changes'
    END as pending_changes_summary,
    
    pending_additions as pending_new_underliers,
    active_workflows as active_rebalancing_workflows,
    
    -- Status indicators
    CASE 
        WHEN active_workflows > 0 THEN 'REBALANCING_IN_PROGRESS'
        WHEN pending_additions > 0 THEN 'PENDING_ADDITIONS'
        WHEN pending_version IS NOT NULL THEN 'PENDING_APPROVAL'
        ELSE 'STABLE'
    END as dynamic_status

FROM CurrentBasketState
ORDER BY group_name;

-- =============================================================================
-- QUERY 2: DYNAMIC UNDERLIER ADDITION PIPELINE
-- =============================================================================

-- Shows all pending/active dynamic additions with impact analysis
SELECT 
    dua.addition_id,
    dua.group_id,
    tg.group_name,
    dua.new_underlier_symbol,
    dua.new_underlier_name,
    dua.new_underlier_sector,
    
    -- Target allocation
    FORMAT(dua.target_weight * 100, 'N2') + '%' as target_weight_pct,
    FORMAT(dua.target_notional, 'C') as target_notional,
    
    -- Addition details
    dua.addition_source,
    dua.addition_rationale,
    dua.execution_priority,
    dua.execution_timeline,
    dua.weight_rebalance_method,
    
    -- Impact analysis
    dua.rebalance_trades_required,
    JSON_VALUE(dua.expected_benefit, '$.expected_alpha') as expected_alpha_bps,
    JSON_VALUE(dua.expected_benefit, '$.diversification_benefit') as diversification_score,
    
    -- Status and timing
    dua.addition_status,
    dua.requested_by,
    dua.requested_date,
    dua.reviewed_by,
    dua.review_date,
    
    -- Associated workflow
    rw.workflow_id,
    rw.workflow_status,
    rw.completion_percentage,
    rw.estimated_execution_time,
    
    -- Days pending
    DATEDIFF(day, dua.requested_date, GETDATE()) as days_pending,
    
    -- Urgency indicator
    CASE 
        WHEN dua.execution_priority = 'HIGH' AND DATEDIFF(day, dua.requested_date, GETDATE()) > 2 THEN 'OVERDUE'
        WHEN dua.execution_priority = 'MEDIUM' AND DATEDIFF(day, dua.requested_date, GETDATE()) > 5 THEN 'OVERDUE'
        WHEN dua.execution_priority = 'LOW' AND DATEDIFF(day, dua.requested_date, GETDATE()) > 10 THEN 'OVERDUE'
        ELSE 'ON_TRACK'
    END as urgency_status

FROM DynamicUnderlierAddition dua
JOIN TradeGroup tg ON dua.group_id = tg.group_id
LEFT JOIN RebalancingWorkflow rw ON dua.group_id = rw.group_id 
    AND dua.version_id = rw.version_id
WHERE dua.addition_status NOT IN ('COMPLETED', 'REJECTED', 'FAILED')
ORDER BY 
    CASE dua.execution_priority WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,
    dua.requested_date;

-- =============================================================================
-- QUERY 3: REBALANCING EXECUTION MONITOR
-- =============================================================================

-- Real-time monitoring of rebalancing workflows and individual trades
SELECT 
    rw.workflow_id,
    rw.group_id,
    tg.group_name,
    rw.workflow_type,
    
    -- Progress metrics
    rw.total_trades_required,
    rw.completed_trades,
    rw.failed_trades,
    FORMAT(rw.completion_percentage, 'N2') + '%' as completion_pct,
    
    -- Execution details
    rw.execution_strategy,
    rw.execution_urgency,
    FORMAT(rw.max_market_impact_bps, 'N2') + ' bps' as max_market_impact,
    rw.estimated_execution_time,
    rw.actual_start_time,
    
    -- Risk monitoring
    rw.current_tracking_error,
    FORMAT(rw.current_cash_balance, 'C') as cash_balance,
    rw.risk_limit_breaches,
    FORMAT(rw.max_position_deviation_pct, 'N2') + '%' as max_position_deviation,
    
    -- Status and timing
    rw.workflow_status,
    rw.created_by,
    
    -- Individual trade details (JSON aggregation)
    (
        SELECT 
            JSON_QUERY((
                SELECT 
                    rt.underlier_symbol,
                    rt.trade_type,
                    rt.side,
                    FORMAT(rt.target_notional, 'C') as target_notional,
                    rt.execution_status,
                    rt.execution_sequence
                FROM RebalancingTrade rt 
                WHERE rt.workflow_id = rw.workflow_id
                ORDER BY rt.execution_sequence
                FOR JSON PATH
            ))
    ) as individual_trades,
    
    -- Time elapsed
    CASE 
        WHEN rw.actual_start_time IS NOT NULL THEN
            DATEDIFF(minute, rw.actual_start_time, COALESCE(rw.actual_end_time, GETDATE()))
        ELSE NULL
    END as execution_minutes,
    
    -- Performance vs estimate
    CASE 
        WHEN rw.actual_end_time IS NOT NULL AND rw.estimated_execution_time IS NOT NULL THEN
            DATEDIFF(minute, rw.estimated_execution_time, rw.actual_end_time)
        ELSE NULL
    END as vs_estimate_minutes

FROM RebalancingWorkflow rw
JOIN TradeGroup tg ON rw.group_id = tg.group_id
WHERE rw.workflow_status IN ('PLANNED', 'APPROVED', 'EXECUTING', 'PAUSED')
ORDER BY 
    CASE rw.execution_urgency WHEN 'URGENT' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'NORMAL' THEN 3 ELSE 4 END,
    rw.created_timestamp;

-- =============================================================================
-- QUERY 4: COMPOSITION EVOLUTION ANALYSIS
-- =============================================================================

-- Tracks how basket composition has evolved over time
WITH CompositionEvolution AS (
    SELECT 
        bcv.group_id,
        bcv.version_number,
        bcv.version_date,
        bcv.version_type,
        bcv.change_reason,
        bcv.target_composition,
        bcv.expected_turnover_pct,
        bcv.version_status,
        
        -- Parse composition to extract individual weights
        JSON_QUERY(bcv.target_composition) as composition_json,
        
        -- Previous version for comparison
        LAG(bcv.target_composition) OVER (
            PARTITION BY bcv.group_id 
            ORDER BY bcv.version_number
        ) as previous_composition,
        
        LAG(bcv.version_date) OVER (
            PARTITION BY bcv.group_id 
            ORDER BY bcv.version_number
        ) as previous_version_date

    FROM BasketCompositionVersion bcv
)
SELECT 
    ce.group_id,
    tg.group_name,
    ce.version_number,
    ce.version_date,
    ce.version_type,
    ce.change_reason,
    
    -- Composition details
    ce.target_composition as current_weights,
    ce.previous_composition as previous_weights,
    
    -- Evolution metrics
    FORMAT(ce.expected_turnover_pct, 'N2') + '%' as expected_turnover,
    
    -- Time between changes
    CASE 
        WHEN ce.previous_version_date IS NOT NULL THEN
            DATEDIFF(day, ce.previous_version_date, ce.version_date)
        ELSE NULL
    END as days_since_last_change,
    
    -- Version lifecycle
    ce.version_status,
    
    -- Extract number of positions
    (SELECT COUNT(*) FROM OPENJSON(ce.target_composition)) as number_of_positions,
    (SELECT COUNT(*) FROM OPENJSON(ce.previous_composition)) as previous_number_of_positions,
    
    -- Position count change
    CASE 
        WHEN ce.previous_composition IS NOT NULL THEN
            (SELECT COUNT(*) FROM OPENJSON(ce.target_composition)) - 
            (SELECT COUNT(*) FROM OPENJSON(ce.previous_composition))
        ELSE NULL
    END as position_count_change

FROM CompositionEvolution ce
JOIN TradeGroup tg ON ce.group_id = tg.group_id
ORDER BY ce.group_id, ce.version_number DESC;

-- =============================================================================
-- QUERY 5: DYNAMIC ADDITION APPROVAL WORKFLOW
-- =============================================================================

-- Support query for approval workflows and impact analysis
SELECT 
    dua.addition_id,
    dua.group_id,
    tg.group_name,
    dua.new_underlier_symbol,
    dua.new_underlier_sector,
    
    -- Request details
    FORMAT(dua.target_weight * 100, 'N2') + '%' as requested_weight,
    FORMAT(dua.target_notional, 'C') as requested_notional,
    dua.addition_rationale,
    dua.execution_priority,
    
    -- Current version impact
    bcv.version_number as current_version,
    bcv.target_composition as current_composition,
    
    -- Proposed changes
    bcv_new.target_composition as proposed_composition,
    FORMAT(bcv_new.expected_turnover_pct, 'N2') + '%' as expected_turnover,
    FORMAT(bcv_new.estimated_execution_cost, 'C') as estimated_cost,
    FORMAT(bcv_new.estimated_market_impact_bps, 'N2') + ' bps' as estimated_impact,
    
    -- Rebalancing requirements
    dua.weight_rebalance_method,
    dua.affected_positions,
    dua.rebalance_trades_required,
    
    -- Approval status
    dua.addition_status,
    dua.requested_by,
    dua.requested_date,
    dua.reviewed_by,
    dua.review_date,
    dua.review_notes,
    
    -- Expected benefits
    JSON_VALUE(dua.expected_benefit, '$.expected_alpha') as expected_alpha,
    JSON_VALUE(dua.expected_benefit, '$.diversification_benefit') as diversification_benefit,
    JSON_VALUE(dua.expected_benefit, '$.risk_adjusted_return_improvement') as risk_improvement,
    
    -- Time in queue
    DATEDIFF(day, dua.requested_date, GETDATE()) as days_in_review,
    
    -- SLA status
    CASE 
        WHEN dua.addition_status = 'REQUESTED' AND DATEDIFF(day, dua.requested_date, GETDATE()) > 3 THEN 'SLA_BREACH'
        WHEN dua.addition_status = 'UNDER_REVIEW' AND DATEDIFF(day, dua.requested_date, GETDATE()) > 5 THEN 'SLA_BREACH'
        ELSE 'WITHIN_SLA'
    END as sla_status

FROM DynamicUnderlierAddition dua
JOIN TradeGroup tg ON dua.group_id = tg.group_id
LEFT JOIN BasketCompositionVersion bcv ON dua.group_id = bcv.group_id 
    AND bcv.version_status = 'ACTIVE'
LEFT JOIN BasketCompositionVersion bcv_new ON dua.version_id = bcv_new.version_id
WHERE dua.addition_status IN ('REQUESTED', 'UNDER_REVIEW', 'APPROVED')
ORDER BY 
    CASE dua.addition_status 
        WHEN 'REQUESTED' THEN 1 
        WHEN 'UNDER_REVIEW' THEN 2 
        WHEN 'APPROVED' THEN 3 
    END,
    dua.requested_date;

-- =============================================================================
-- QUERY 6: HISTORICAL IMPACT ANALYSIS
-- =============================================================================

-- Analyzes the historical impact of dynamic additions
SELECT 
    bch.group_id,
    tg.group_name,
    bch.change_date,
    bch.change_type,
    bch.change_reason,
    bch.initiated_by,
    bch.approved_by,
    
    -- Composition changes
    JSON_VALUE(bch.change_details, '$.new_additions[0].symbol') as added_symbol,
    JSON_VALUE(bch.change_details, '$.new_additions[0].initial_weight') as added_weight,
    JSON_VALUE(bch.change_details, '$.new_additions[0].rationale') as addition_rationale,
    
    -- Impact metrics
    FORMAT(bch.turnover_generated, 'N2') + '%' as actual_turnover,
    FORMAT(bch.execution_cost_incurred, 'C') as actual_execution_cost,
    FORMAT(bch.tracking_error_impact, 'N6') as tracking_error_impact,
    
    -- Count of affected positions
    (SELECT COUNT(*) FROM OPENJSON(bch.change_details, '$.weight_adjustments')) as positions_rebalanced,
    
    -- Days since change
    DATEDIFF(day, bch.change_date, GETDATE()) as days_since_change,
    
    -- Success metrics (would be populated from performance data)
    NULL as performance_impact_30d, -- Placeholder for actual performance tracking
    NULL as alpha_generated_30d,    -- Placeholder for alpha measurement
    
    -- Composition before/after position count
    (SELECT COUNT(*) FROM OPENJSON(bch.composition_before)) as positions_before,
    (SELECT COUNT(*) FROM OPENJSON(bch.composition_after)) as positions_after

FROM BasketCompositionHistory bch
JOIN TradeGroup tg ON bch.group_id = tg.group_id
WHERE bch.change_type IN ('ADDITION', 'REBALANCE')
ORDER BY bch.change_date DESC;

-- =============================================================================
-- OPERATIONAL DASHBOARD QUERY
-- =============================================================================

-- Summary dashboard for dynamic basket management operations
SELECT 
    -- Summary statistics
    COUNT(DISTINCT tg.group_id) as total_baskets,
    
    -- Dynamic addition metrics
    SUM(CASE WHEN dua.addition_status = 'REQUESTED' THEN 1 ELSE 0 END) as pending_requests,
    SUM(CASE WHEN dua.addition_status = 'UNDER_REVIEW' THEN 1 ELSE 0 END) as under_review,
    SUM(CASE WHEN dua.addition_status = 'APPROVED' THEN 1 ELSE 0 END) as approved_awaiting_execution,
    
    -- Rebalancing workflow metrics
    SUM(CASE WHEN rw.workflow_status = 'EXECUTING' THEN 1 ELSE 0 END) as active_rebalancing,
    SUM(CASE WHEN rw.workflow_status = 'PAUSED' THEN 1 ELSE 0 END) as paused_workflows,
    
    -- Risk metrics
    AVG(rw.completion_percentage) as avg_rebalancing_completion,
    MAX(rw.risk_limit_breaches) as max_risk_breaches,
    
    -- Processing time metrics
    AVG(CASE 
        WHEN dua.addition_status = 'APPROVED' AND dua.review_date IS NOT NULL 
        THEN DATEDIFF(day, dua.requested_date, dua.review_date)
        ELSE NULL
    END) as avg_approval_days,
    
    -- Current active basket versions
    COUNT(DISTINCT bcv.version_id) as active_versions,
    
    -- Last update timestamp
    GETDATE() as dashboard_timestamp

FROM TradeGroup tg
LEFT JOIN DynamicUnderlierAddition dua ON tg.group_id = dua.group_id
LEFT JOIN RebalancingWorkflow rw ON tg.group_id = rw.group_id
LEFT JOIN BasketCompositionVersion bcv ON tg.group_id = bcv.group_id AND bcv.version_status = 'ACTIVE'
WHERE tg.group_type = 'BASKET_STRATEGY';
