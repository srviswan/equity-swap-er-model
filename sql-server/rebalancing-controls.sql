-- Rebalancing Controls and Optimization for High-Volume Trading
-- Prevents excessive rebalancing and manages high-frequency trade environments
-- Microsoft SQL Server Implementation

-- =============================================================================
-- REBALANCING FREQUENCY CONTROLS
-- =============================================================================

-- RebalancingSchedule table - Controls when rebalancing can occur
CREATE TABLE RebalancingSchedule (
    schedule_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Frequency controls
    rebalancing_frequency VARCHAR(30) NOT NULL CHECK (rebalancing_frequency IN (
        'INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'EVENT_DRIVEN', 'THRESHOLD_BASED')),
    
    -- Timing constraints
    allowed_time_windows NVARCHAR(MAX), -- JSON: Time windows when rebalancing is allowed
    blackout_periods NVARCHAR(MAX), -- JSON: Periods when rebalancing is prohibited
    minimum_interval_hours INTEGER DEFAULT 24, -- Minimum hours between rebalancing
    
    -- Threshold-based triggers
    max_weight_deviation_pct DECIMAL(5,2) DEFAULT 5.00, -- Max deviation before rebalancing
    max_tracking_error_threshold DECIMAL(10,6) DEFAULT 0.0050, -- 50bps tracking error limit
    min_cash_balance_trigger DECIMAL(18,2), -- Cash balance that triggers rebalancing
    
    -- Volume and impact controls
    max_daily_turnover_pct DECIMAL(5,2) DEFAULT 10.00, -- Max daily turnover allowed
    max_rebalancing_cost_threshold DECIMAL(18,2), -- Cost threshold for approval
    market_impact_limit_bps DECIMAL(8,2) DEFAULT 50.00, -- Market impact limit
    
    -- Status and overrides
    schedule_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (schedule_status IN (
        'ACTIVE', 'SUSPENDED', 'MAINTENANCE')),
    emergency_override_allowed BIT DEFAULT 1,
    
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    last_updated DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_rebalancing_schedule_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id) ON DELETE CASCADE
);

-- RebalancingEvent table - Tracks all rebalancing events and their triggers
CREATE TABLE RebalancingEvent (
    event_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Event classification
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN (
        'SCHEDULED_REBALANCE', 'THRESHOLD_BREACH', 'INDEX_CHANGE', 'CORPORATE_ACTION',
        'EMERGENCY_REBALANCE', 'STRATEGIC_ADJUSTMENT', 'RISK_MANAGEMENT')),
    event_trigger VARCHAR(500), -- What triggered this rebalancing event
    
    -- Timing information
    event_timestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
    evaluation_timestamp DATETIME2, -- When thresholds were evaluated
    scheduled_execution_time DATETIME2, -- When execution is planned
    
    -- Current state analysis
    current_composition NVARCHAR(MAX), -- JSON: Current basket composition
    target_composition NVARCHAR(MAX), -- JSON: Target composition
    deviation_analysis NVARCHAR(MAX), -- JSON: Deviation metrics
    
    -- Decision factors
    tracking_error_current DECIMAL(10,6),
    cash_balance_current DECIMAL(18,2),
    largest_weight_deviation_pct DECIMAL(5,2),
    estimated_rebalancing_cost DECIMAL(18,2),
    estimated_market_impact_bps DECIMAL(8,2),
    
    -- Event decision
    event_status VARCHAR(20) DEFAULT 'PENDING' CHECK (event_status IN (
        'PENDING', 'APPROVED', 'REJECTED', 'EXECUTED', 'CANCELLED')),
    decision_reason NVARCHAR(MAX),
    decision_by VARCHAR(100),
    decision_timestamp DATETIME2,
    
    -- Execution tracking
    workflow_id VARCHAR(50), -- Links to RebalancingWorkflow if executed
    execution_start_time DATETIME2,
    execution_end_time DATETIME2,
    actual_cost_incurred DECIMAL(18,2),
    actual_market_impact_bps DECIMAL(8,2),
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_rebalancing_event_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_rebalancing_event_workflow
        FOREIGN KEY (workflow_id) REFERENCES RebalancingWorkflow(workflow_id)
);

-- TradeAggregation table - Aggregates regular trades for periodic evaluation
CREATE TABLE TradeAggregation (
    aggregation_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Aggregation period
    aggregation_date DATE NOT NULL,
    aggregation_period VARCHAR(20) NOT NULL CHECK (aggregation_period IN (
        'INTRADAY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    period_start_time DATETIME2 NOT NULL,
    period_end_time DATETIME2 NOT NULL,
    
    -- Trade volume metrics
    total_trades_count INTEGER DEFAULT 0,
    total_volume_traded DECIMAL(18,2) DEFAULT 0,
    total_notional_traded DECIMAL(18,2) DEFAULT 0,
    
    -- Position impact analysis
    net_position_changes NVARCHAR(MAX), -- JSON: Net position changes by underlier
    cash_flows_generated DECIMAL(18,2), -- Net cash from all trades
    current_weights NVARCHAR(MAX), -- JSON: Current actual weights
    target_weights NVARCHAR(MAX), -- JSON: Target weights from active version
    weight_deviations NVARCHAR(MAX), -- JSON: Deviation from target by underlier
    
    -- Risk metrics
    tracking_error_contribution DECIMAL(10,6),
    largest_position_deviation_pct DECIMAL(5,2),
    risk_limit_utilization_pct DECIMAL(5,2),
    
    -- Rebalancing recommendation
    rebalancing_recommended BIT DEFAULT 0,
    recommendation_reason NVARCHAR(MAX),
    estimated_rebalancing_trades INTEGER,
    estimated_rebalancing_cost DECIMAL(18,2),
    
    aggregation_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (aggregation_status IN (
        'ACTIVE', 'PROCESSED', 'ARCHIVED')),
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    processed_timestamp DATETIME2,
    
    CONSTRAINT fk_trade_aggregation_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- RebalancingThreshold table - Configurable thresholds for different scenarios
CREATE TABLE RebalancingThreshold (
    threshold_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    threshold_name VARCHAR(100) NOT NULL,
    
    -- Threshold configuration
    threshold_type VARCHAR(30) NOT NULL CHECK (threshold_type IN (
        'WEIGHT_DEVIATION', 'TRACKING_ERROR', 'CASH_BALANCE', 'POSITION_COUNT',
        'SECTOR_CONCENTRATION', 'LIQUIDITY_SCORE', 'RISK_BUDGET')),
    
    threshold_value DECIMAL(18,6) NOT NULL,
    threshold_unit VARCHAR(20) NOT NULL, -- 'PERCENT', 'ABSOLUTE', 'BASIS_POINTS', 'COUNT'
    
    -- Threshold behavior
    evaluation_frequency VARCHAR(20) DEFAULT 'DAILY' CHECK (evaluation_frequency IN (
        'REAL_TIME', 'HOURLY', 'DAILY', 'WEEKLY')),
    breach_action VARCHAR(30) DEFAULT 'ALERT' CHECK (breach_action IN (
        'ALERT', 'AUTO_REBALANCE', 'MANUAL_REVIEW', 'EMERGENCY_STOP')),
    
    -- Alert configuration
    alert_stakeholders NVARCHAR(MAX), -- JSON: List of people to alert
    escalation_threshold_multiplier DECIMAL(5,2) DEFAULT 1.5, -- When to escalate
    
    threshold_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (threshold_status IN (
        'ACTIVE', 'SUSPENDED', 'TESTING')),
    
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    last_breach_timestamp DATETIME2,
    breach_count_30d INTEGER DEFAULT 0,
    
    CONSTRAINT fk_rebalancing_threshold_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- =============================================================================
-- BATCH PROCESSING AND OPTIMIZATION
-- =============================================================================

-- RebalancingBatch table - Groups multiple rebalancing events for efficient execution
CREATE TABLE RebalancingBatch (
    batch_id VARCHAR(50) PRIMARY KEY,
    
    -- Batch composition
    batch_date DATE NOT NULL,
    included_groups NVARCHAR(MAX), -- JSON: List of group_ids in batch
    total_groups_count INTEGER NOT NULL,
    
    -- Execution strategy
    batch_execution_strategy VARCHAR(30) DEFAULT 'PARALLEL' CHECK (batch_execution_strategy IN (
        'PARALLEL', 'SEQUENTIAL', 'PRIORITY_BASED', 'RISK_OPTIMIZED')),
    execution_time_window_start DATETIME2,
    execution_time_window_end DATETIME2,
    
    -- Resource management
    max_concurrent_workflows INTEGER DEFAULT 5,
    total_estimated_trades INTEGER,
    total_estimated_cost DECIMAL(18,2),
    total_estimated_market_impact_bps DECIMAL(8,2),
    
    -- Batch status
    batch_status VARCHAR(20) DEFAULT 'PLANNED' CHECK (batch_status IN (
        'PLANNED', 'APPROVED', 'EXECUTING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    
    -- Execution tracking
    workflows_started INTEGER DEFAULT 0,
    workflows_completed INTEGER DEFAULT 0,
    workflows_failed INTEGER DEFAULT 0,
    
    actual_start_time DATETIME2,
    actual_end_time DATETIME2,
    actual_total_cost DECIMAL(18,2),
    actual_market_impact_bps DECIMAL(8,2),
    
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    approved_by VARCHAR(100),
    approval_timestamp DATETIME2
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- RebalancingSchedule indexes
CREATE INDEX idx_rebalancing_schedule_group ON RebalancingSchedule(group_id, schedule_status);
CREATE INDEX idx_rebalancing_schedule_frequency ON RebalancingSchedule(rebalancing_frequency, schedule_status);

-- RebalancingEvent indexes
CREATE INDEX idx_rebalancing_event_group_type ON RebalancingEvent(group_id, event_type, event_timestamp);
CREATE INDEX idx_rebalancing_event_status ON RebalancingEvent(event_status, event_timestamp);
CREATE INDEX idx_rebalancing_event_trigger ON RebalancingEvent(event_type, event_timestamp);

-- TradeAggregation indexes
CREATE INDEX idx_trade_aggregation_group_date ON TradeAggregation(group_id, aggregation_date);
CREATE INDEX idx_trade_aggregation_period ON TradeAggregation(aggregation_period, aggregation_date);
CREATE INDEX idx_trade_aggregation_recommendation ON TradeAggregation(rebalancing_recommended, aggregation_date);

-- RebalancingThreshold indexes
CREATE INDEX idx_rebalancing_threshold_group_type ON RebalancingThreshold(group_id, threshold_type);
CREATE INDEX idx_rebalancing_threshold_status ON RebalancingThreshold(threshold_status, evaluation_frequency);

-- RebalancingBatch indexes
CREATE INDEX idx_rebalancing_batch_date ON RebalancingBatch(batch_date, batch_status);
CREATE INDEX idx_rebalancing_batch_status ON RebalancingBatch(batch_status, created_timestamp);

-- =============================================================================
-- SAMPLE CONFIGURATION DATA
-- =============================================================================

-- Example rebalancing schedule for a technology basket
INSERT INTO RebalancingSchedule (
    schedule_id, group_id, rebalancing_frequency,
    allowed_time_windows, minimum_interval_hours,
    max_weight_deviation_pct, max_tracking_error_threshold,
    max_daily_turnover_pct, market_impact_limit_bps,
    created_by
) VALUES (
    'SCHED_TECH_001',
    'GRP_TECH_BASKET_001',
    'THRESHOLD_BASED',
    '{"morning_window": {"start": "09:30", "end": "11:30"}, "afternoon_window": {"start": "14:00", "end": "15:30"}}',
    24, -- Minimum 24 hours between rebalancing
    3.00, -- Max 3% weight deviation
    0.0025, -- 25bps tracking error limit
    5.00, -- Max 5% daily turnover
    25.00, -- Max 25bps market impact
    'PORTFOLIO_MANAGER_001'
);

-- Example threshold configuration
INSERT INTO RebalancingThreshold (
    threshold_id, group_id, threshold_name, threshold_type,
    threshold_value, threshold_unit, evaluation_frequency,
    breach_action, alert_stakeholders, created_by
) VALUES 
('THRESH_TECH_WEIGHT', 'GRP_TECH_BASKET_001', 'Maximum Weight Deviation', 'WEIGHT_DEVIATION',
 3.0, 'PERCENT', 'DAILY', 'MANUAL_REVIEW', 
 '["PORTFOLIO_MANAGER_001", "RISK_MANAGER_001"]', 'RISK_MANAGER_001'),

('THRESH_TECH_TRACKING', 'GRP_TECH_BASKET_001', 'Tracking Error Limit', 'TRACKING_ERROR',
 25.0, 'BASIS_POINTS', 'DAILY', 'ALERT', 
 '["PORTFOLIO_MANAGER_001", "QUANTITATIVE_ANALYST_001"]', 'RISK_MANAGER_001'),

('THRESH_TECH_CASH', 'GRP_TECH_BASKET_001', 'Excess Cash Balance', 'CASH_BALANCE',
 500000.0, 'ABSOLUTE', 'DAILY', 'AUTO_REBALANCE', 
 '["PORTFOLIO_MANAGER_001"]', 'PORTFOLIO_MANAGER_001');
