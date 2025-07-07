-- Client Flow Management for High-Frequency Basket Trading
-- Handles frequent client in/out trading without constant rebalancing
-- Microsoft SQL Server Implementation

-- =============================================================================
-- CLIENT FLOW TRACKING TABLES
-- =============================================================================

-- ClientBasketPosition table - Tracks each client's position in basket strategies
CREATE TABLE ClientBasketPosition (
    position_id VARCHAR(50) PRIMARY KEY,
    client_id VARCHAR(50) NOT NULL,
    group_id VARCHAR(50) NOT NULL, -- References TradeGroup (the basket)
    
    -- Position details
    current_units DECIMAL(18,6) NOT NULL DEFAULT 0, -- Client's units in the basket
    current_notional DECIMAL(18,2) NOT NULL DEFAULT 0, -- Current market value
    entry_price DECIMAL(12,6), -- Client's average entry price per unit
    
    -- Flow tracking
    total_subscriptions DECIMAL(18,2) DEFAULT 0, -- Total client purchases
    total_redemptions DECIMAL(18,2) DEFAULT 0, -- Total client sales
    unrealized_pnl DECIMAL(18,2) DEFAULT 0, -- Mark-to-market P&L
    
    -- Position status
    position_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (position_status IN (
        'ACTIVE', 'CLOSED', 'SUSPENDED')),
    
    last_trade_timestamp DATETIME2,
    position_opened_date DATE,
    position_closed_date DATE,
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    last_updated DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_client_basket_position_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    
    -- Unique constraint - one position per client per basket
    CONSTRAINT uk_client_basket_position UNIQUE (client_id, group_id)
);

-- ClientFlowEvent table - Records all client subscription/redemption activities
CREATE TABLE ClientFlowEvent (
    flow_event_id VARCHAR(50) PRIMARY KEY,
    client_id VARCHAR(50) NOT NULL,
    group_id VARCHAR(50) NOT NULL,
    
    -- Flow details
    flow_type VARCHAR(20) NOT NULL CHECK (flow_type IN (
        'SUBSCRIPTION', 'REDEMPTION', 'TRANSFER_IN', 'TRANSFER_OUT')),
    flow_units DECIMAL(18,6) NOT NULL, -- Units traded (positive for sub, negative for redemption)
    flow_price DECIMAL(12,6) NOT NULL, -- Price per unit
    flow_notional DECIMAL(18,2) NOT NULL, -- Total transaction amount
    
    -- Execution details
    execution_timestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
    settlement_date DATE,
    cash_flow DECIMAL(18,2), -- Actual cash movement
    
    -- Source trade information
    source_trade_id VARCHAR(50), -- Links to original Trade table
    trading_desk VARCHAR(50),
    trader_id VARCHAR(50),
    
    -- Flow impact on basket
    basket_nav_before DECIMAL(12,6), -- Basket NAV before this flow
    basket_nav_after DECIMAL(12,6), -- Basket NAV after this flow
    flow_impact_bps DECIMAL(8,2), -- Impact on basket NAV in basis points
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_client_flow_event_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- BasketFlowAggregation table - Aggregates client flows by time periods
CREATE TABLE BasketFlowAggregation (
    aggregation_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Time period
    aggregation_date DATE NOT NULL,
    aggregation_period VARCHAR(20) NOT NULL CHECK (aggregation_period IN (
        'INTRADAY_HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY')),
    period_start_time DATETIME2 NOT NULL,
    period_end_time DATETIME2 NOT NULL,
    
    -- Flow aggregation
    total_subscriptions DECIMAL(18,2) DEFAULT 0,
    total_redemptions DECIMAL(18,2) DEFAULT 0,
    net_flows DECIMAL(18,2) DEFAULT 0, -- Subscriptions - Redemptions
    flow_count INTEGER DEFAULT 0,
    unique_clients_count INTEGER DEFAULT 0,
    
    -- Units and pricing
    total_units_issued DECIMAL(18,6) DEFAULT 0,
    total_units_redeemed DECIMAL(18,6) DEFAULT 0,
    net_units_change DECIMAL(18,6) DEFAULT 0,
    volume_weighted_avg_price DECIMAL(12,6),
    
    -- Basket impact analysis
    opening_nav DECIMAL(12,6),
    closing_nav DECIMAL(12,6),
    nav_change_pct DECIMAL(8,4),
    flow_driven_drift DECIMAL(8,4), -- How much basket composition drifted due to flows
    
    -- Cash management
    cash_generated DECIMAL(18,2), -- Cash from net flows
    cash_deployed DECIMAL(18,2), -- Cash used for rebalancing
    excess_cash_balance DECIMAL(18,2), -- Remaining cash not deployed
    
    -- Rebalancing metrics
    rebalancing_triggered BIT DEFAULT 0,
    estimated_rebalancing_cost DECIMAL(18,2),
    drift_threshold_breached BIT DEFAULT 0,
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_basket_flow_aggregation_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- BasketCashManagement table - Tracks cash flows and deployment
CREATE TABLE BasketCashManagement (
    cash_management_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Cash position
    cash_balance_date DATE NOT NULL,
    opening_cash_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
    closing_cash_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
    
    -- Cash flows during the day
    client_subscriptions_cash DECIMAL(18,2) DEFAULT 0, -- Cash from new subscriptions
    client_redemptions_cash DECIMAL(18,2) DEFAULT 0, -- Cash paid for redemptions
    dividend_income_cash DECIMAL(18,2) DEFAULT 0, -- Dividends received from holdings
    interest_income_cash DECIMAL(18,2) DEFAULT 0, -- Interest on cash balances
    rebalancing_cash_used DECIMAL(18,2) DEFAULT 0, -- Cash deployed for rebalancing
    
    -- Cash thresholds and limits
    min_cash_threshold DECIMAL(18,2) DEFAULT 100000, -- Minimum cash to maintain
    max_cash_threshold DECIMAL(18,2) DEFAULT 1000000, -- Maximum cash before deployment
    cash_utilization_pct DECIMAL(5,2), -- Percentage of available cash deployed
    
    -- Auto-deployment rules
    auto_deployment_enabled BIT DEFAULT 1,
    deployment_batch_size DECIMAL(18,2) DEFAULT 500000, -- Minimum size for deployment
    last_deployment_timestamp DATETIME2,
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_basket_cash_management_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- FlowBasedRebalancingTrigger table - Triggers rebalancing based on flow patterns
CREATE TABLE FlowBasedRebalancingTrigger (
    trigger_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    
    -- Trigger configuration
    trigger_name VARCHAR(100) NOT NULL,
    trigger_type VARCHAR(30) NOT NULL CHECK (trigger_type IN (
        'NET_FLOW_THRESHOLD', 'CASH_ACCUMULATION', 'DRIFT_PERCENTAGE', 
        'SUBSCRIPTION_SURGE', 'REDEMPTION_PRESSURE', 'TIME_BASED')),
    
    -- Threshold settings
    threshold_value DECIMAL(18,6) NOT NULL,
    threshold_unit VARCHAR(20) NOT NULL, -- 'ABSOLUTE', 'PERCENTAGE', 'UNITS', 'TIME_HOURS'
    evaluation_period_hours INTEGER DEFAULT 24, -- Period over which to evaluate
    
    -- Flow pattern analysis
    consecutive_periods_required INTEGER DEFAULT 1, -- How many periods threshold must be breached
    flow_direction VARCHAR(20) CHECK (flow_direction IN ('INFLOW', 'OUTFLOW', 'EITHER')),
    minimum_client_count INTEGER, -- Minimum number of clients involved
    
    -- Rebalancing response
    auto_trigger_rebalancing BIT DEFAULT 0, -- Whether to automatically trigger rebalancing
    rebalancing_urgency VARCHAR(20) DEFAULT 'NORMAL' CHECK (rebalancing_urgency IN (
        'LOW', 'NORMAL', 'HIGH', 'URGENT')),
    target_deployment_pct DECIMAL(5,2) DEFAULT 95.00, -- Target % of excess cash to deploy
    
    -- Status and monitoring
    trigger_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (trigger_status IN (
        'ACTIVE', 'SUSPENDED', 'TESTING')),
    last_trigger_timestamp DATETIME2,
    trigger_count_30d INTEGER DEFAULT 0,
    false_positive_count INTEGER DEFAULT 0,
    
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_flow_rebalancing_trigger_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- =============================================================================
-- PERFORMANCE INDEXES
-- =============================================================================

-- ClientBasketPosition indexes
CREATE INDEX idx_client_basket_position_client ON ClientBasketPosition(client_id, position_status);
CREATE INDEX idx_client_basket_position_group ON ClientBasketPosition(group_id, position_status);
CREATE INDEX idx_client_basket_position_updated ON ClientBasketPosition(last_updated, group_id);

-- ClientFlowEvent indexes
CREATE INDEX idx_client_flow_event_timestamp ON ClientFlowEvent(execution_timestamp, group_id);
CREATE INDEX idx_client_flow_event_client ON ClientFlowEvent(client_id, execution_timestamp);
CREATE INDEX idx_client_flow_event_type ON ClientFlowEvent(flow_type, execution_timestamp);
CREATE INDEX idx_client_flow_event_group_date ON ClientFlowEvent(group_id, CAST(execution_timestamp AS DATE));

-- BasketFlowAggregation indexes
CREATE INDEX idx_basket_flow_aggregation_date ON BasketFlowAggregation(group_id, aggregation_date);
CREATE INDEX idx_basket_flow_aggregation_period ON BasketFlowAggregation(aggregation_period, aggregation_date);
CREATE INDEX idx_basket_flow_aggregation_rebalancing ON BasketFlowAggregation(rebalancing_triggered, aggregation_date);

-- BasketCashManagement indexes
CREATE INDEX idx_basket_cash_management_date ON BasketCashManagement(group_id, cash_balance_date);
CREATE INDEX idx_basket_cash_management_balance ON BasketCashManagement(closing_cash_balance, cash_balance_date);

-- FlowBasedRebalancingTrigger indexes
CREATE INDEX idx_flow_rebalancing_trigger_group ON FlowBasedRebalancingTrigger(group_id, trigger_status);
CREATE INDEX idx_flow_rebalancing_trigger_type ON FlowBasedRebalancingTrigger(trigger_type, trigger_status);

-- =============================================================================
-- SAMPLE CONFIGURATION DATA
-- =============================================================================

-- Example flow-based rebalancing triggers
INSERT INTO FlowBasedRebalancingTrigger (
    trigger_id, group_id, trigger_name, trigger_type,
    threshold_value, threshold_unit, evaluation_period_hours,
    auto_trigger_rebalancing, rebalancing_urgency, target_deployment_pct,
    created_by
) VALUES 
-- Cash accumulation trigger
('TRIGGER_TECH_CASH', 'GRP_TECH_BASKET_001', 'Excess Cash Deployment', 'CASH_ACCUMULATION',
 2000000.0, 'ABSOLUTE', 4, 1, 'NORMAL', 90.00, 'PORTFOLIO_MANAGER_001'),

-- Large subscription surge trigger  
('TRIGGER_TECH_SURGE', 'GRP_TECH_BASKET_001', 'Subscription Surge Response', 'SUBSCRIPTION_SURGE',
 5000000.0, 'ABSOLUTE', 2, 1, 'HIGH', 95.00, 'PORTFOLIO_MANAGER_001'),

-- Net flow threshold trigger
('TRIGGER_TECH_NETFLOW', 'GRP_TECH_BASKET_001', 'Net Flow Threshold', 'NET_FLOW_THRESHOLD',
 10000000.0, 'ABSOLUTE', 24, 0, 'NORMAL', 85.00, 'PORTFOLIO_MANAGER_001'),

-- Drift percentage trigger
('TRIGGER_TECH_DRIFT', 'GRP_TECH_BASKET_001', 'Composition Drift Control', 'DRIFT_PERCENTAGE',
 2.5, 'PERCENTAGE', 12, 0, 'HIGH', 100.00, 'RISK_MANAGER_001');

-- Example basket cash management configuration
INSERT INTO BasketCashManagement (
    cash_management_id, group_id, cash_balance_date,
    opening_cash_balance, closing_cash_balance,
    min_cash_threshold, max_cash_threshold,
    auto_deployment_enabled, deployment_batch_size
) VALUES (
    'CASH_MGT_TECH_001',
    'GRP_TECH_BASKET_001',
    CAST(GETDATE() AS DATE),
    500000.00, -- Opening cash
    750000.00, -- Closing cash
    200000.00, -- Min threshold - always keep $200K
    3000000.00, -- Max threshold - deploy above $3M
    1, -- Auto-deployment enabled
    1000000.00 -- Deploy in $1M batches
);
