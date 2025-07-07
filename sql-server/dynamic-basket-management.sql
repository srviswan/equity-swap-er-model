-- Dynamic Basket Management for Equity Swaps
-- Handles dynamic addition/removal of underliers to existing basket strategies
-- Microsoft SQL Server Implementation

-- =============================================================================
-- DYNAMIC BASKET COMPOSITION MANAGEMENT
-- =============================================================================

-- BasketCompositionVersion table - Versioned basket definitions
CREATE TABLE BasketCompositionVersion (
    version_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    version_number INTEGER NOT NULL,
    version_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    version_type VARCHAR(30) NOT NULL CHECK (version_type IN (
        'INITIAL', 'ADDITION', 'REMOVAL', 'REBALANCE', 'CORPORATE_ACTION', 'INDEX_CHANGE')),
    target_composition NVARCHAR(MAX) NOT NULL, -- JSON: New target weights
    previous_composition NVARCHAR(MAX), -- JSON: Previous weights for comparison
    composition_changes NVARCHAR(MAX), -- JSON: Detailed change log
    
    -- Change metadata
    change_reason VARCHAR(500),
    change_requested_by VARCHAR(100),
    change_approved_by VARCHAR(100),
    change_approval_date DATETIME2,
    effective_date DATETIME2,
    
    -- Impact analysis
    expected_turnover_pct DECIMAL(8,4), -- Expected portfolio turnover
    estimated_execution_cost DECIMAL(18,2),
    estimated_market_impact_bps DECIMAL(8,2),
    risk_impact_summary NVARCHAR(MAX), -- JSON: Risk metrics changes
    
    version_status VARCHAR(20) DEFAULT 'PENDING' CHECK (version_status IN (
        'PENDING', 'APPROVED', 'REJECTED', 'ACTIVE', 'SUPERSEDED')),
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    activated_timestamp DATETIME2,
    
    CONSTRAINT fk_basket_version_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id) ON DELETE CASCADE,
    CONSTRAINT uq_basket_version_number
        UNIQUE (group_id, version_number)
);

-- DynamicUnderlierAddition table - Tracks new underlier requests
CREATE TABLE DynamicUnderlierAddition (
    addition_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    version_id VARCHAR(50) NOT NULL,
    
    -- New underlier details
    new_underlier_symbol VARCHAR(20) NOT NULL,
    new_underlier_name VARCHAR(200),
    new_underlier_sector VARCHAR(50),
    new_underlier_country CHAR(3),
    target_weight DECIMAL(10,6) NOT NULL CHECK (target_weight > 0 AND target_weight <= 1),
    target_notional DECIMAL(18,2),
    
    -- Sourcing and rationale
    addition_source VARCHAR(50) CHECK (addition_source IN (
        'INDEX_ADDITION', 'STRATEGIC_DECISION', 'OPPORTUNISTIC', 'RISK_MANAGEMENT', 
        'CORPORATE_ACTION', 'CLIENT_REQUEST', 'REGULATORY_REQUIREMENT')),
    addition_rationale NVARCHAR(MAX),
    expected_benefit NVARCHAR(MAX), -- JSON: Expected impact metrics
    
    -- Execution planning
    execution_priority VARCHAR(10) DEFAULT 'MEDIUM' CHECK (execution_priority IN ('HIGH', 'MEDIUM', 'LOW')),
    execution_timeline VARCHAR(50), -- Target execution timeframe
    execution_constraints NVARCHAR(MAX), -- JSON: Special execution requirements
    
    -- Weight rebalancing impact
    weight_rebalance_method VARCHAR(30) CHECK (weight_rebalance_method IN (
        'PRO_RATA_REDUCTION', 'TARGETED_REDUCTION', 'CASH_INJECTION', 'SECTOR_NEUTRAL')),
    affected_positions NVARCHAR(MAX), -- JSON: Positions affected by rebalancing
    rebalance_trades_required INTEGER DEFAULT 0,
    
    -- Status tracking
    addition_status VARCHAR(20) DEFAULT 'REQUESTED' CHECK (addition_status IN (
        'REQUESTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'EXECUTING', 'COMPLETED', 'FAILED')),
    
    requested_by VARCHAR(100) NOT NULL,
    requested_date DATETIME2 DEFAULT GETDATE(),
    reviewed_by VARCHAR(100),
    review_date DATETIME2,
    review_notes NVARCHAR(MAX),
    
    CONSTRAINT fk_dynamic_addition_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_dynamic_addition_version
        FOREIGN KEY (version_id) REFERENCES BasketCompositionVersion(version_id)
);

-- RebalancingWorkflow table - Manages rebalancing execution
CREATE TABLE RebalancingWorkflow (
    workflow_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    version_id VARCHAR(50) NOT NULL,
    workflow_type VARCHAR(30) NOT NULL CHECK (workflow_type IN (
        'ADDITION_REBALANCE', 'REMOVAL_REBALANCE', 'WEIGHT_ADJUSTMENT', 'FULL_RECONSTITUTION')),
    
    -- Workflow planning
    total_trades_required INTEGER NOT NULL,
    completed_trades INTEGER DEFAULT 0,
    failed_trades INTEGER DEFAULT 0,
    estimated_execution_time DATETIME2,
    actual_start_time DATETIME2,
    actual_end_time DATETIME2,
    
    -- Execution parameters
    execution_strategy VARCHAR(50) CHECK (execution_strategy IN (
        'SIMULTANEOUS', 'SEQUENTIAL', 'BATCH_EXECUTION', 'TWAP', 'VWAP', 'IMPLEMENTATION_SHORTFALL')),
    max_market_impact_bps DECIMAL(8,2) DEFAULT 25.00, -- Maximum allowed market impact
    execution_urgency VARCHAR(20) DEFAULT 'NORMAL' CHECK (execution_urgency IN (
        'LOW', 'NORMAL', 'HIGH', 'URGENT')),
    
    -- Progress tracking
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    current_tracking_error DECIMAL(10,6),
    current_cash_balance DECIMAL(18,2),
    
    -- Risk controls
    risk_limit_breaches INTEGER DEFAULT 0,
    max_position_deviation_pct DECIMAL(5,2) DEFAULT 5.00,
    intraday_risk_monitoring BIT DEFAULT 1,
    
    workflow_status VARCHAR(20) DEFAULT 'PLANNED' CHECK (workflow_status IN (
        'PLANNED', 'APPROVED', 'EXECUTING', 'PAUSED', 'COMPLETED', 'FAILED', 'CANCELLED')),
    
    created_by VARCHAR(100) NOT NULL,
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_rebalancing_workflow_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_rebalancing_workflow_version
        FOREIGN KEY (version_id) REFERENCES BasketCompositionVersion(version_id)
);

-- RebalancingTrade table - Individual trades in rebalancing workflow
CREATE TABLE RebalancingTrade (
    rebalancing_trade_id VARCHAR(50) PRIMARY KEY,
    workflow_id VARCHAR(50) NOT NULL,
    trade_id VARCHAR(50), -- Links to actual Trade when executed
    
    -- Trade details
    underlier_symbol VARCHAR(20) NOT NULL,
    trade_type VARCHAR(20) NOT NULL CHECK (trade_type IN (
        'NEW_ADDITION', 'WEIGHT_INCREASE', 'WEIGHT_DECREASE', 'FULL_LIQUIDATION')),
    side VARCHAR(10) NOT NULL CHECK (side IN ('BUY', 'SELL')),
    
    -- Size and timing
    target_quantity DECIMAL(18,6),
    target_notional DECIMAL(18,2),
    target_weight_change DECIMAL(10,6), -- Change in basket weight
    execution_sequence INTEGER,
    
    -- Current vs target
    current_weight DECIMAL(10,6),
    target_weight DECIMAL(10,6),
    weight_adjustment DECIMAL(10,6),
    
    -- Execution tracking
    execution_status VARCHAR(20) DEFAULT 'PENDING' CHECK (execution_status IN (
        'PENDING', 'STAGED', 'SUBMITTED', 'PARTIAL_FILL', 'FILLED', 'CANCELLED', 'FAILED')),
    execution_timestamp DATETIME2,
    filled_quantity DECIMAL(18,6) DEFAULT 0,
    average_fill_price DECIMAL(18,6),
    execution_venue VARCHAR(100),
    
    -- Dependencies and constraints
    dependency_trade_id VARCHAR(50), -- Must complete before this trade
    execution_constraint NVARCHAR(MAX), -- JSON: Special constraints
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_rebalancing_trade_workflow
        FOREIGN KEY (workflow_id) REFERENCES RebalancingWorkflow(workflow_id) ON DELETE CASCADE,
    CONSTRAINT fk_rebalancing_trade_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT fk_rebalancing_trade_dependency
        FOREIGN KEY (dependency_trade_id) REFERENCES RebalancingTrade(rebalancing_trade_id)
);

-- BasketCompositionHistory table - Audit trail of all changes
CREATE TABLE BasketCompositionHistory (
    history_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    change_date DATETIME2 NOT NULL,
    change_type VARCHAR(30) NOT NULL,
    
    -- Before and after snapshots
    composition_before NVARCHAR(MAX), -- JSON: Composition before change
    composition_after NVARCHAR(MAX), -- JSON: Composition after change
    change_details NVARCHAR(MAX), -- JSON: Detailed change breakdown
    
    -- Impact metrics
    turnover_generated DECIMAL(8,4), -- Actual turnover percentage
    execution_cost_incurred DECIMAL(18,2),
    tracking_error_impact DECIMAL(10,6),
    
    -- Metadata
    initiated_by VARCHAR(100),
    approved_by VARCHAR(100),
    executed_by VARCHAR(100),
    change_reason VARCHAR(500),
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_basket_history_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id)
);

-- =============================================================================
-- INDEXES FOR DYNAMIC BASKET MANAGEMENT
-- =============================================================================

-- BasketCompositionVersion indexes
CREATE INDEX idx_basket_version_group_number ON BasketCompositionVersion(group_id, version_number);
CREATE INDEX idx_basket_version_status_date ON BasketCompositionVersion(version_status, version_date);
CREATE INDEX idx_basket_version_type ON BasketCompositionVersion(version_type, effective_date);

-- DynamicUnderlierAddition indexes
CREATE INDEX idx_dynamic_addition_group ON DynamicUnderlierAddition(group_id, addition_status);
CREATE INDEX idx_dynamic_addition_symbol ON DynamicUnderlierAddition(new_underlier_symbol, requested_date);
CREATE INDEX idx_dynamic_addition_source ON DynamicUnderlierAddition(addition_source, requested_date);

-- RebalancingWorkflow indexes
CREATE INDEX idx_rebalancing_workflow_group ON RebalancingWorkflow(group_id, workflow_status);
CREATE INDEX idx_rebalancing_workflow_type ON RebalancingWorkflow(workflow_type, created_timestamp);
CREATE INDEX idx_rebalancing_workflow_status ON RebalancingWorkflow(workflow_status, completion_percentage);

-- RebalancingTrade indexes
CREATE INDEX idx_rebalancing_trade_workflow ON RebalancingTrade(workflow_id, execution_sequence);
CREATE INDEX idx_rebalancing_trade_symbol ON RebalancingTrade(underlier_symbol, execution_status);
CREATE INDEX idx_rebalancing_trade_status ON RebalancingTrade(execution_status, execution_timestamp);

-- BasketCompositionHistory indexes
CREATE INDEX idx_basket_history_group_date ON BasketCompositionHistory(group_id, change_date);
CREATE INDEX idx_basket_history_type ON BasketCompositionHistory(change_type, change_date);
CREATE INDEX idx_basket_history_user ON BasketCompositionHistory(initiated_by, change_date);

-- =============================================================================
-- SAMPLE DATA - DYNAMIC BASKET SCENARIOS
-- =============================================================================

-- Example 1: Initial basket composition version
INSERT INTO BasketCompositionVersion (
    version_id, group_id, version_number, version_type,
    target_composition, change_reason, change_requested_by,
    change_approved_by, change_approval_date, effective_date,
    expected_turnover_pct, version_status, activated_timestamp
) VALUES (
    'VER_TECH_001_V1',
    'GRP_TECH_BASKET_001',
    1,
    'INITIAL',
    '{"AAPL": 25.0, "MSFT": 20.0, "GOOGL": 15.0, "AMZN": 15.0, "TSLA": 10.0, "NVDA": 15.0}',
    'Initial basket composition for Technology Sector strategy',
    'PORTFOLIO_MANAGER_001',
    'RISK_MANAGER_001',
    DATEADD(day, -30, GETDATE()),
    DATEADD(day, -30, GETDATE()),
    0.00,
    'ACTIVE',
    DATEADD(day, -30, GETDATE())
);

-- Example 2: Dynamic addition of new underlier (META)
INSERT INTO BasketCompositionVersion (
    version_id, group_id, version_number, version_type,
    target_composition, previous_composition, composition_changes,
    change_reason, change_requested_by, expected_turnover_pct,
    estimated_execution_cost, estimated_market_impact_bps,
    version_status
) VALUES (
    'VER_TECH_001_V2',
    'GRP_TECH_BASKET_001',
    2,
    'ADDITION',
    '{"AAPL": 22.0, "MSFT": 18.0, "GOOGL": 13.0, "AMZN": 13.0, "TSLA": 9.0, "NVDA": 13.0, "META": 12.0}',
    '{"AAPL": 25.0, "MSFT": 20.0, "GOOGL": 15.0, "AMZN": 15.0, "TSLA": 10.0, "NVDA": 15.0}',
    '{"additions": [{"symbol": "META", "weight": 12.0, "reason": "Strong Q2 earnings and AI initiatives"}], "reductions": [{"AAPL": -3.0}, {"MSFT": -2.0}, {"GOOGL": -2.0}, {"AMZN": -2.0}, {"TSLA": -1.0}, {"NVDA": -2.0}]}',
    'Add META to basket following strong Q2 2024 earnings and increased AI investment focus',
    'PORTFOLIO_MANAGER_001',
    8.50, -- 8.5% turnover expected
    45000.00, -- $45K estimated execution cost
    12.50, -- 12.5 bps estimated market impact
    'PENDING'
);

-- Dynamic underlier addition request
INSERT INTO DynamicUnderlierAddition (
    addition_id, group_id, version_id, new_underlier_symbol, new_underlier_name,
    new_underlier_sector, new_underlier_country, target_weight, target_notional,
    addition_source, addition_rationale, expected_benefit,
    execution_priority, execution_timeline, weight_rebalance_method,
    affected_positions, rebalance_trades_required, addition_status,
    requested_by, requested_date
) VALUES (
    'ADD_META_001',
    'GRP_TECH_BASKET_001',
    'VER_TECH_001_V2',
    'META',
    'Meta Platforms Inc',
    'Technology',
    'USA',
    0.1200, -- 12% target weight
    1200000.00,
    'STRATEGIC_DECISION',
    'Strong Q2 earnings, increased AI investment, and improved user engagement metrics make META attractive addition to technology basket',
    '{"expected_alpha": 2.5, "diversification_benefit": 1.8, "risk_adjusted_return_improvement": 0.35}',
    'HIGH',
    'Within 3 business days',
    'PRO_RATA_REDUCTION',
    '{"AAPL": -3.0, "MSFT": -2.0, "GOOGL": -2.0, "AMZN": -2.0, "TSLA": -1.0, "NVDA": -2.0}',
    6, -- 6 rebalancing trades needed
    'APPROVED',
    'PORTFOLIO_MANAGER_001',
    GETDATE()
);

-- Rebalancing workflow for META addition
INSERT INTO RebalancingWorkflow (
    workflow_id, group_id, version_id, workflow_type,
    total_trades_required, estimated_execution_time,
    execution_strategy, max_market_impact_bps, execution_urgency,
    max_position_deviation_pct, workflow_status, created_by
) VALUES (
    'WF_META_ADD_001',
    'GRP_TECH_BASKET_001',
    'VER_TECH_001_V2',
    'ADDITION_REBALANCE',
    7, -- 1 new buy + 6 rebalancing sells
    DATEADD(hour, 8, GETDATE()), -- 8 hours estimated
    'IMPLEMENTATION_SHORTFALL',
    15.00, -- Max 15 bps market impact
    'HIGH',
    3.00, -- Max 3% position deviation
    'APPROVED',
    'EXECUTION_TRADER_001'
);

-- Individual rebalancing trades
INSERT INTO RebalancingTrade (
    rebalancing_trade_id, workflow_id, underlier_symbol, trade_type, side,
    target_quantity, target_notional, target_weight_change,
    current_weight, target_weight, weight_adjustment, execution_sequence,
    execution_status
) VALUES 
-- New META position
('RBT_META_BUY_001', 'WF_META_ADD_001', 'META', 'NEW_ADDITION', 'BUY', 
 2400.00, 1200000.00, 12.0, 0.0, 12.0, 12.0, 1, 'PENDING'),

-- Reduce existing positions
('RBT_AAPL_SELL_001', 'WF_META_ADD_001', 'AAPL', 'WEIGHT_DECREASE', 'SELL',
 1875.00, 300000.00, -3.0, 25.0, 22.0, -3.0, 2, 'PENDING'),

('RBT_MSFT_SELL_001', 'WF_META_ADD_001', 'MSFT', 'WEIGHT_DECREASE', 'SELL',
 625.00, 200000.00, -2.0, 20.0, 18.0, -2.0, 3, 'PENDING'),

('RBT_GOOGL_SELL_001', 'WF_META_ADD_001', 'GOOGL', 'WEIGHT_DECREASE', 'SELL',
 125.00, 200000.00, -2.0, 15.0, 13.0, -2.0, 4, 'PENDING'),

('RBT_AMZN_SELL_001', 'WF_META_ADD_001', 'AMZN', 'WEIGHT_DECREASE', 'SELL',
 1111.11, 200000.00, -2.0, 15.0, 13.0, -2.0, 5, 'PENDING'),

('RBT_TSLA_SELL_001', 'WF_META_ADD_001', 'TSLA', 'WEIGHT_DECREASE', 'SELL',
 416.67, 100000.00, -1.0, 10.0, 9.0, -1.0, 6, 'PENDING'),

('RBT_NVDA_SELL_001', 'WF_META_ADD_001', 'NVDA', 'WEIGHT_DECREASE', 'SELL',
 166.67, 200000.00, -2.0, 15.0, 13.0, -2.0, 7, 'PENDING');

-- Historical record of the change
INSERT INTO BasketCompositionHistory (
    history_id, group_id, change_date, change_type,
    composition_before, composition_after, change_details,
    turnover_generated, initiated_by, approved_by, change_reason
) VALUES (
    'HIST_TECH_META_ADD',
    'GRP_TECH_BASKET_001',
    GETDATE(),
    'ADDITION',
    '{"AAPL": 25.0, "MSFT": 20.0, "GOOGL": 15.0, "AMZN": 15.0, "TSLA": 10.0, "NVDA": 15.0}',
    '{"AAPL": 22.0, "MSFT": 18.0, "GOOGL": 13.0, "AMZN": 13.0, "TSLA": 9.0, "NVDA": 13.0, "META": 12.0}',
    '{"new_additions": [{"symbol": "META", "initial_weight": 12.0, "rationale": "AI and metaverse exposure"}], "weight_adjustments": [{"symbol": "AAPL", "change": -3.0}, {"symbol": "MSFT", "change": -2.0}, {"symbol": "GOOGL", "change": -2.0}, {"symbol": "AMZN", "change": -2.0}, {"symbol": "TSLA", "change": -1.0}, {"symbol": "NVDA", "change": -2.0}]}',
    8.50,
    'PORTFOLIO_MANAGER_001',
    'CIO_001',
    'Strategic addition of META for AI and metaverse exposure following strong earnings'
);
