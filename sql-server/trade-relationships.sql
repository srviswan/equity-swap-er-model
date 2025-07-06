-- Trade Relationship Management for Independent Component Trades
-- This extension supports systems that capture individual underlier trades
-- independently but need to group them into logical basket strategies
-- MS SQL Server Implementation

-- TradeGroup table - Logical grouping of related trades
CREATE TABLE TradeGroup (
    group_id VARCHAR(50) PRIMARY KEY,
    group_name VARCHAR(200) NOT NULL,
    group_type VARCHAR(30) NOT NULL CHECK (group_type IN (
        'BASKET_STRATEGY', 'HEDGE_PAIR', 'SPREAD_TRADE', 'PORTFOLIO_TRADE')),
    strategy_description NVARCHAR(MAX),
    parent_product_id VARCHAR(50), -- References the logical basket product
    group_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (group_status IN (
        'BUILDING', 'ACTIVE', 'PARTIAL_FILLED', 'COMPLETED', 'CANCELLED')),
    target_total_notional DECIMAL(18,2),
    target_currency CHAR(3),
    execution_start_time DATETIME2,
    execution_end_time DATETIME2,
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE()
);

-- TradeGroupMember table - Links individual trades to groups
CREATE TABLE TradeGroupMember (
    group_member_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    trade_id VARCHAR(50) NOT NULL,
    member_role VARCHAR(30) CHECK (member_role IN (
        'PRIMARY_LEG', 'HEDGE_LEG', 'BASKET_COMPONENT', 'SPREAD_LEG')),
    target_weight DECIMAL(10,6), -- Expected weight in the basket
    actual_weight DECIMAL(10,6), -- Actual achieved weight
    target_notional DECIMAL(18,2), -- Expected notional amount
    actual_notional DECIMAL(18,2), -- Actual executed amount
    execution_sequence INTEGER, -- Order of execution (1, 2, 3...)
    execution_priority VARCHAR(10) CHECK (execution_priority IN ('HIGH', 'MEDIUM', 'LOW')),
    hedge_ratio DECIMAL(10,6), -- For hedge relationships
    is_required BIT DEFAULT 1, -- Must be filled for group completion
    fill_status VARCHAR(20) DEFAULT 'PENDING' CHECK (fill_status IN (
        'PENDING', 'PARTIAL', 'FILLED', 'CANCELLED', 'FAILED')),
    dependency_trade_id VARCHAR(50), -- Trade that must execute first
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT fk_trade_group_member_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id) ON DELETE CASCADE,
    CONSTRAINT fk_trade_group_member_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_trade_group_dependency
        FOREIGN KEY (dependency_trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT uq_trade_group_member 
        UNIQUE (group_id, trade_id),
    CONSTRAINT ck_trade_group_member_weights
        CHECK (target_weight IS NULL OR (target_weight >= 0 AND target_weight <= 1)),
    CONSTRAINT ck_trade_group_member_actual_weights
        CHECK (actual_weight IS NULL OR (actual_weight >= 0 AND actual_weight <= 1))
);

-- ExecutionSequence table - Tracks detailed execution timing and performance
CREATE TABLE ExecutionSequence (
    execution_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    trade_id VARCHAR(50) NOT NULL,
    sequence_number INTEGER NOT NULL,
    execution_timestamp DATETIME2 NOT NULL,
    execution_venue VARCHAR(100),
    execution_algorithm VARCHAR(50),
    pre_trade_price DECIMAL(18,6),
    execution_price DECIMAL(18,6),
    post_trade_price DECIMAL(18,6),
    market_impact_bps DECIMAL(8,2), -- Basis points of market impact
    timing_alpha_bps DECIMAL(8,2), -- Timing alpha in basis points
    slippage_bps DECIMAL(8,2), -- Execution slippage
    execution_cost DECIMAL(18,2),
    execution_notes NVARCHAR(MAX),
    
    CONSTRAINT fk_execution_sequence_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_execution_sequence_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT uq_execution_sequence
        UNIQUE (group_id, trade_id, sequence_number)
);

-- BasketReconstitution table - Tracks basket building progress
CREATE TABLE BasketReconstitution (
    reconstitution_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    reconstitution_date DATE NOT NULL,
    target_composition NVARCHAR(MAX) NOT NULL, -- JSON: Expected basket composition
    current_composition NVARCHAR(MAX), -- JSON: Current composition
    completion_percentage DECIMAL(5,2) DEFAULT 0.00 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),
    tracking_error DECIMAL(10,6), -- Tracking error vs target
    total_deviation DECIMAL(18,2), -- Total notional deviation
    remaining_trades INTEGER DEFAULT 0,
    estimated_completion DATETIME2,
    recon_status VARCHAR(20) DEFAULT 'IN_PROGRESS' CHECK (recon_status IN (
        'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')),
    
    -- Risk metrics
    portfolio_beta DECIMAL(8,4),
    portfolio_vega DECIMAL(18,2),
    concentration_risk DECIMAL(5,2), -- Largest single position %
    
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    completed_timestamp DATETIME2,
    
    CONSTRAINT fk_basket_recon_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id) ON DELETE CASCADE
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- TradeGroup indexes
CREATE INDEX idx_trade_group_type_status ON TradeGroup(group_type, group_status);
CREATE INDEX idx_trade_group_product ON TradeGroup(parent_product_id);
CREATE INDEX idx_trade_group_execution_time ON TradeGroup(execution_start_time, execution_end_time);

-- TradeGroupMember indexes
CREATE INDEX idx_trade_group_member_group ON TradeGroupMember(group_id, fill_status);
CREATE INDEX idx_trade_group_member_trade ON TradeGroupMember(trade_id);
CREATE INDEX idx_trade_group_member_sequence ON TradeGroupMember(execution_sequence, execution_priority);
CREATE INDEX idx_trade_group_member_dependency ON TradeGroupMember(dependency_trade_id);

-- ExecutionSequence indexes
CREATE INDEX idx_execution_sequence_group_time ON ExecutionSequence(group_id, execution_timestamp);
CREATE INDEX idx_execution_sequence_trade ON ExecutionSequence(trade_id, sequence_number);
CREATE INDEX idx_execution_sequence_venue ON ExecutionSequence(execution_venue, execution_timestamp);

-- BasketReconstitution indexes
CREATE INDEX idx_basket_recon_group_date ON BasketReconstitution(group_id, reconstitution_date);
CREATE INDEX idx_basket_recon_status ON BasketReconstitution(recon_status, completion_percentage);
CREATE INDEX idx_basket_recon_completion ON BasketReconstitution(estimated_completion, recon_status);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Sample Trade Group for Technology Basket Strategy
INSERT INTO TradeGroup (
    group_id, group_name, group_type, strategy_description,
    group_status, target_total_notional, target_currency,
    execution_start_time, created_by
) VALUES (
    'GRP_TECH_BASKET_001',
    'Technology Sector Equity Basket',
    'BASKET_STRATEGY',
    'Long technology sector exposure through individual stock trades grouped as basket strategy',
    'BUILDING',
    10000000.00,
    'USD',
    GETDATE(),
    'PORTFOLIO_MANAGER_001'
);

-- Sample reconstitution tracking
INSERT INTO BasketReconstitution (
    reconstitution_id, group_id, reconstitution_date,
    target_composition, completion_percentage, remaining_trades,
    recon_status
) VALUES (
    'RECON_TECH_001',
    'GRP_TECH_BASKET_001', 
    CAST(GETDATE() AS DATE),
    '{"AAPL": 25.0, "MSFT": 20.0, "GOOGL": 15.0, "AMZN": 15.0, "TSLA": 10.0, "NVDA": 15.0}',
    15.50,
    5,
    'IN_PROGRESS'
);
