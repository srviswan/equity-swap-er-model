-- Trade Relationship Management for Independent Component Trades
-- This extension supports systems that capture individual underlier trades
-- independently but need to group them into logical basket strategies

-- TradeGroup table - Logical grouping of related trades
CREATE TABLE TradeGroup (
    group_id VARCHAR(50) PRIMARY KEY,
    group_name VARCHAR(200) NOT NULL,
    group_type VARCHAR(30) NOT NULL CHECK (group_type IN (
        'BASKET_STRATEGY', 'HEDGE_PAIR', 'SPREAD_TRADE', 'PORTFOLIO_TRADE')),
    strategy_description TEXT,
    parent_product_id VARCHAR(50), -- References the logical basket product
    group_status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (group_status IN (
        'BUILDING', 'ACTIVE', 'PARTIAL_FILLED', 'COMPLETED', 'CANCELLED')),
    target_total_notional DECIMAL(18,2),
    target_currency CHAR(3),
    execution_start_time TIMESTAMP,
    execution_end_time TIMESTAMP,
    created_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    is_required BOOLEAN DEFAULT TRUE, -- Must be filled for group completion
    fill_status VARCHAR(20) DEFAULT 'PENDING' CHECK (fill_status IN (
        'PENDING', 'PARTIAL', 'FILLED', 'CANCELLED', 'FAILED')),
    dependency_trade_id VARCHAR(50), -- Trade that must execute first
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_trade_group_member_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id) ON DELETE CASCADE,
    CONSTRAINT fk_trade_group_member_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_trade_group_dependency
        FOREIGN KEY (dependency_trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT uq_trade_group_member 
        UNIQUE (group_id, trade_id),
    CONSTRAINT ck_weights_positive
        CHECK (target_weight IS NULL OR target_weight > 0),
    CONSTRAINT ck_notionals_positive  
        CHECK (target_notional IS NULL OR target_notional > 0)
);

-- ExecutionSequence table - Tracks execution order and timing
CREATE TABLE ExecutionSequence (
    sequence_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    trade_id VARCHAR(50) NOT NULL,
    sequence_number INTEGER NOT NULL,
    execution_time TIMESTAMP NOT NULL,
    execution_price DECIMAL(18,6),
    execution_quantity DECIMAL(18,6),
    execution_notional DECIMAL(18,2),
    market_impact_bps DECIMAL(8,2), -- Market impact in basis points
    timing_alpha_bps DECIMAL(8,2), -- Alpha from execution timing
    execution_venue VARCHAR(100),
    execution_algorithm VARCHAR(50),
    slippage_bps DECIMAL(8,2), -- Slippage vs target price
    
    CONSTRAINT fk_execution_sequence_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_execution_sequence_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT uq_execution_sequence
        UNIQUE (group_id, sequence_number)
);

-- BasketReconstitution table - Links component trades to basket definition
CREATE TABLE BasketReconstitution (
    reconstitution_id VARCHAR(50) PRIMARY KEY,
    group_id VARCHAR(50) NOT NULL,
    target_basket_id VARCHAR(50), -- Reference to Underlier basket
    reconstitution_date DATE NOT NULL,
    reconstitution_type VARCHAR(30) CHECK (reconstitution_type IN (
        'INITIAL_BUILD', 'REBALANCE', 'CORPORATE_ACTION', 'MANUAL_ADJUSTMENT')),
    
    -- Target vs Actual Analysis
    target_composition JSONB, -- JSON of target weights
    actual_composition JSONB, -- JSON of achieved weights  
    tracking_error_bps DECIMAL(8,2), -- Difference from target
    
    -- Execution Statistics
    total_execution_time_minutes INTEGER,
    total_market_impact_bps DECIMAL(8,2),
    average_fill_ratio DECIMAL(6,4), -- Average fill across components
    
    reconstitution_status VARCHAR(20) DEFAULT 'IN_PROGRESS' CHECK (reconstitution_status IN (
        'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')),
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    
    notes TEXT,
    created_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_basket_reconstitution_group
        FOREIGN KEY (group_id) REFERENCES TradeGroup(group_id),
    CONSTRAINT fk_basket_reconstitution_basket
        FOREIGN KEY (target_basket_id) REFERENCES Underlier(underlier_id),
    CONSTRAINT ck_completion_percentage
        CHECK (completion_percentage >= 0 AND completion_percentage <= 100)
);

-- Indexes for performance
CREATE INDEX idx_trade_group_status ON TradeGroup(group_status, created_timestamp);
CREATE INDEX idx_trade_group_member_group ON TradeGroupMember(group_id, execution_sequence);
CREATE INDEX idx_trade_group_member_trade ON TradeGroupMember(trade_id, fill_status);
CREATE INDEX idx_execution_sequence_group_time ON ExecutionSequence(group_id, execution_time);
CREATE INDEX idx_basket_reconstitution_date ON BasketReconstitution(reconstitution_date, reconstitution_status);

-- Sample data for Technology Basket executed as separate trades
INSERT INTO TradeGroup VALUES (
    'GRP001', 
    'Technology Basket Variance Swap - Component Execution',
    'BASKET_STRATEGY',
    'Technology basket variance swap executed as individual component trades',
    'PROD003', -- References basket product
    'COMPLETED',
    2000000.00,
    'USD',
    '2024-01-02 14:30:00',
    '2024-01-02 14:38:45',
    'TRADER001',
    '2024-01-02 14:25:00'
);

INSERT INTO TradeGroupMember VALUES 
-- Apple component  
('GM001', 'GRP001', 'TRD003_AAPL', 'BASKET_COMPONENT', 0.40, 0.398, 800000.00, 798500.00, 1, 'HIGH', NULL, TRUE, 'FILLED', NULL, '2024-01-02 14:30:15'),
-- Microsoft component
('GM002', 'GRP001', 'TRD003_MSFT', 'BASKET_COMPONENT', 0.35, 0.352, 700000.00, 703200.00, 2, 'HIGH', NULL, TRUE, 'FILLED', 'TRD003_AAPL', '2024-01-02 14:32:22'),
-- Alphabet component  
('GM003', 'GRP001', 'TRD003_GOOGL', 'BASKET_COMPONENT', 0.25, 0.250, 500000.00, 498300.00, 3, 'MEDIUM', NULL, TRUE, 'FILLED', 'TRD003_MSFT', '2024-01-02 14:35:18');

INSERT INTO ExecutionSequence VALUES
('ES001', 'GRP001', 'TRD003_AAPL', 1, '2024-01-02 14:30:15', 180.52, 4424.89, 798500.00, 2.3, 0.8, 'NASDAQ', 'TWAP', 1.2),
('ES002', 'GRP001', 'TRD003_MSFT', 2, '2024-01-02 14:32:22', 375.12, 1874.15, 703200.00, 3.1, -0.4, 'NASDAQ', 'POV', 2.1),
('ES003', 'GRP001', 'TRD003_GOOGL', 3, '2024-01-02 14:35:18', 140.25, 3553.28, 498300.00, 1.8, 1.2, 'NASDAQ', 'ARRIVAL_PRICE', 0.9);
