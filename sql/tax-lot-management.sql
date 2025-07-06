-- Tax Lot Management System for Equity Swaps
-- Supports various tax lot efficiency methodologies during unwinds and partial terminations
-- LIFO, FIFO, HICO (Highest Cost), LOCO (Lowest Cost), Specific ID, Average Cost

-- TaxLot table - Individual tax lots for position tracking
CREATE TABLE TaxLot (
    tax_lot_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    lot_number INTEGER NOT NULL,
    
    -- Position details
    original_notional DECIMAL(18,2) NOT NULL CHECK (original_notional > 0),
    current_notional DECIMAL(18,2) NOT NULL CHECK (current_notional >= 0),
    original_shares DECIMAL(18,6),
    current_shares DECIMAL(18,6),
    
    -- Cost basis tracking
    cost_basis DECIMAL(18,6) NOT NULL, -- Per share/unit cost basis
    total_cost_basis DECIMAL(18,2) NOT NULL, -- Total cost basis for lot
    
    -- Timing information
    acquisition_date DATE NOT NULL,
    acquisition_time TIMESTAMP NOT NULL,
    holding_period_start_date DATE NOT NULL,
    
    -- Tax classification
    tax_classification VARCHAR(30) CHECK (tax_classification IN (
        'SHORT_TERM', 'LONG_TERM', 'SECTION_1256', 'ORDINARY', 'CAPITAL')),
    wash_sale_adjustment DECIMAL(18,2) DEFAULT 0.00,
    
    -- Lot status
    lot_status VARCHAR(20) DEFAULT 'OPEN' CHECK (lot_status IN (
        'OPEN', 'PARTIALLY_CLOSED', 'FULLY_CLOSED', 'TRANSFERRED')),
    
    -- References
    source_execution_id VARCHAR(50), -- Links to original execution
    opening_trade_event_id VARCHAR(50), -- TradeEvent that opened this lot
    
    -- Audit fields
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_tax_lot_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_tax_lot_opening_event
        FOREIGN KEY (opening_trade_event_id) REFERENCES TradeEvent(event_id),
    CONSTRAINT ck_tax_lot_notional_consistency
        CHECK (current_notional <= original_notional),
    CONSTRAINT ck_tax_lot_shares_consistency  
        CHECK (current_shares IS NULL OR original_shares IS NULL OR current_shares <= original_shares),
    CONSTRAINT uq_tax_lot_trade_number
        UNIQUE (trade_id, lot_number)
);

-- TaxLotUnwindMethodology table - Configuration for unwind methodologies
CREATE TABLE TaxLotUnwindMethodology (
    methodology_id VARCHAR(50) PRIMARY KEY,
    methodology_name VARCHAR(100) NOT NULL,
    methodology_type VARCHAR(30) NOT NULL CHECK (methodology_type IN (
        'LIFO', 'FIFO', 'HICO', 'LOCO', 'SPECIFIC_ID', 'AVERAGE_COST', 'TAX_OPTIMIZED')),
    
    -- Configuration parameters
    sort_criteria JSONB NOT NULL, -- JSON array of sort fields and order
    selection_rules JSONB, -- Additional selection logic
    
    -- Tax optimization settings
    optimize_for VARCHAR(20) CHECK (optimize_for IN (
        'MIN_GAIN', 'MAX_LOSS', 'MIN_TAX', 'LONG_TERM_PREFERRED', 'SHORT_TERM_PREFERRED')),
    wash_sale_aware BOOLEAN DEFAULT TRUE,
    
    -- Description and usage
    description TEXT,
    applicable_scenarios JSONB, -- When to use this methodology
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    created_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ck_methodology_sort_criteria
        CHECK (jsonb_typeof(sort_criteria) = 'array')
);

-- TaxLotUnwind table - Records of tax lot unwinds during trade terminations
CREATE TABLE TaxLotUnwind (
    unwind_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    unwind_event_id VARCHAR(50), -- Links to TradeEvent (PARTIAL_TERMINATION/FULL_TERMINATION)
    
    -- Unwind request details
    requested_notional DECIMAL(18,2) NOT NULL CHECK (requested_notional > 0),
    requested_shares DECIMAL(18,6),
    unwind_date DATE NOT NULL,
    unwind_time TIMESTAMP NOT NULL,
    
    -- Methodology used
    methodology_id VARCHAR(50) NOT NULL,
    methodology_override_reason TEXT, -- If default methodology was overridden
    
    -- Aggregate results
    total_unwound_notional DECIMAL(18,2) DEFAULT 0.00,
    total_unwound_shares DECIMAL(18,6) DEFAULT 0.00,
    lots_affected_count INTEGER DEFAULT 0,
    
    -- Tax implications
    total_realized_gain_loss DECIMAL(18,2) DEFAULT 0.00,
    short_term_gain_loss DECIMAL(18,2) DEFAULT 0.00,
    long_term_gain_loss DECIMAL(18,2) DEFAULT 0.00,
    wash_sale_adjustment DECIMAL(18,2) DEFAULT 0.00,
    
    -- Status and processing
    unwind_status VARCHAR(20) DEFAULT 'PENDING' CHECK (unwind_status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED')),
    processing_notes TEXT,
    
    -- References and audit
    processed_by VARCHAR(100),
    approved_by VARCHAR(100), -- For manual/override cases
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_timestamp TIMESTAMP,
    
    CONSTRAINT fk_tax_lot_unwind_trade
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id),
    CONSTRAINT fk_tax_lot_unwind_event
        FOREIGN KEY (unwind_event_id) REFERENCES TradeEvent(event_id),
    CONSTRAINT fk_tax_lot_unwind_methodology
        FOREIGN KEY (methodology_id) REFERENCES TaxLotUnwindMethodology(methodology_id),
    CONSTRAINT ck_unwind_notional_positive
        CHECK (total_unwound_notional >= 0 AND total_unwound_notional <= requested_notional)
);

-- TaxLotUnwindDetail table - Individual lot-level unwind details
CREATE TABLE TaxLotUnwindDetail (
    unwind_detail_id VARCHAR(50) PRIMARY KEY,
    unwind_id VARCHAR(50) NOT NULL,
    tax_lot_id VARCHAR(50) NOT NULL,
    
    -- Unwind amounts from this lot
    unwound_notional DECIMAL(18,2) NOT NULL CHECK (unwound_notional > 0),
    unwound_shares DECIMAL(18,6),
    unwind_percentage DECIMAL(8,4) NOT NULL CHECK (unwind_percentage > 0 AND unwind_percentage <= 1),
    
    -- Cost basis and P&L calculation
    cost_basis_per_unit DECIMAL(18,6) NOT NULL,
    total_cost_basis DECIMAL(18,2) NOT NULL,
    market_value_per_unit DECIMAL(18,6) NOT NULL,
    total_market_value DECIMAL(18,2) NOT NULL,
    realized_gain_loss DECIMAL(18,2) NOT NULL,
    
    -- Tax classification
    holding_period_days INTEGER NOT NULL,
    tax_classification VARCHAR(30) NOT NULL,
    wash_sale_applied BOOLEAN DEFAULT FALSE,
    wash_sale_amount DECIMAL(18,2) DEFAULT 0.00,
    
    -- Selection metadata
    selection_order INTEGER NOT NULL, -- Order in which lots were selected
    selection_criteria JSONB, -- Why this lot was selected
    
    -- Processing details
    unwind_price DECIMAL(18,6) NOT NULL,
    unwind_timestamp TIMESTAMP NOT NULL,
    
    CONSTRAINT fk_tax_lot_unwind_detail_unwind
        FOREIGN KEY (unwind_id) REFERENCES TaxLotUnwind(unwind_id) ON DELETE CASCADE,
    CONSTRAINT fk_tax_lot_unwind_detail_lot
        FOREIGN KEY (tax_lot_id) REFERENCES TaxLot(tax_lot_id),
    CONSTRAINT ck_unwind_percentage_valid
        CHECK (unwind_percentage > 0 AND unwind_percentage <= 1.0000)
);

-- TaxLotAdjustment table - Corporate actions, splits, dividends affecting tax lots
CREATE TABLE TaxLotAdjustment (
    adjustment_id VARCHAR(50) PRIMARY KEY,
    tax_lot_id VARCHAR(50) NOT NULL,
    adjustment_type VARCHAR(30) NOT NULL CHECK (adjustment_type IN (
        'STOCK_SPLIT', 'STOCK_DIVIDEND', 'CASH_DIVIDEND', 'MERGER', 'SPINOFF', 
        'RIGHTS_OFFERING', 'RETURN_OF_CAPITAL', 'WASH_SALE', 'COST_BASIS_ADJUSTMENT')),
    
    -- Adjustment details
    adjustment_date DATE NOT NULL,
    effective_date DATE NOT NULL,
    
    -- Before adjustment
    shares_before DECIMAL(18,6),
    cost_basis_before DECIMAL(18,6),
    total_cost_basis_before DECIMAL(18,2),
    
    -- After adjustment  
    shares_after DECIMAL(18,6),
    cost_basis_after DECIMAL(18,6),
    total_cost_basis_after DECIMAL(18,2),
    
    -- Adjustment ratios and amounts
    adjustment_ratio VARCHAR(20), -- e.g., "2:1", "3:2"
    cash_amount DECIMAL(18,2) DEFAULT 0.00,
    
    -- References
    corporate_action_id VARCHAR(50), -- Link to corporate action event
    source_event_id VARCHAR(50), -- TradeEvent or other source
    
    -- Description and audit
    adjustment_description TEXT,
    processed_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_tax_lot_adjustment_lot
        FOREIGN KEY (tax_lot_id) REFERENCES TaxLot(tax_lot_id) ON DELETE CASCADE,
    CONSTRAINT fk_tax_lot_adjustment_event
        FOREIGN KEY (source_event_id) REFERENCES TradeEvent(event_id)
);

-- Indexes for performance
CREATE INDEX idx_tax_lot_trade_status ON TaxLot(trade_id, lot_status, acquisition_date);
CREATE INDEX idx_tax_lot_acquisition_date ON TaxLot(acquisition_date, cost_basis);
CREATE INDEX idx_tax_lot_cost_basis ON TaxLot(cost_basis DESC, acquisition_date); -- For HICO methodology
CREATE INDEX idx_tax_lot_cost_basis_asc ON TaxLot(cost_basis ASC, acquisition_date); -- For LOCO methodology
CREATE INDEX idx_tax_lot_unwind_trade_date ON TaxLotUnwind(trade_id, unwind_date);
CREATE INDEX idx_tax_lot_unwind_detail_lot ON TaxLotUnwindDetail(tax_lot_id, unwind_timestamp);
CREATE INDEX idx_tax_lot_adjustment_date ON TaxLotAdjustment(tax_lot_id, adjustment_date);

-- Sample tax lot unwind methodologies
INSERT INTO TaxLotUnwindMethodology VALUES
('METH_LIFO', 'Last In, First Out', 'LIFO', 
 '[{"field": "acquisition_date", "order": "DESC"}, {"field": "acquisition_time", "order": "DESC"}]',
 '{"prefer_recent": true}',
 NULL, TRUE, 
 'Unwind most recently acquired lots first - minimizes record keeping and often provides tax benefits',
 '["partial_termination", "full_termination", "rebalancing"]',
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP),

('METH_FIFO', 'First In, First Out', 'FIFO',
 '[{"field": "acquisition_date", "order": "ASC"}, {"field": "acquisition_time", "order": "ASC"}]',
 '{"prefer_oldest": true}',
 'LONG_TERM_PREFERRED', TRUE,
 'Unwind oldest lots first - maximizes long-term capital gains treatment',
 '["tax_optimization", "long_term_holding"]',
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP),

('METH_HICO', 'Highest Cost First', 'HICO',
 '[{"field": "cost_basis", "order": "DESC"}, {"field": "acquisition_date", "order": "ASC"}]',
 '{"optimize_gain_loss": true}',
 'MIN_GAIN', TRUE,
 'Unwind highest cost basis lots first - minimizes realized gains',
 '["gain_minimization", "tax_loss_harvesting"]', 
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP),

('METH_LOCO', 'Lowest Cost First', 'LOCO',
 '[{"field": "cost_basis", "order": "ASC"}, {"field": "acquisition_date", "order": "ASC"}]',
 '{"optimize_gain_loss": true}',
 'MAX_LOSS', TRUE,
 'Unwind lowest cost basis lots first - maximizes realized losses for tax benefits',
 '["loss_realization", "tax_optimization"]',
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP),

('METH_SPEC', 'Specific Identification', 'SPECIFIC_ID',
 '[{"field": "manual_selection", "order": "ASC"}]',
 '{"manual_override": true, "requires_approval": true}',
 NULL, TRUE,
 'Manually specify exact lots to unwind - maximum control for tax optimization',
 '["complex_strategies", "manual_optimization"]',
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP),

('METH_AVG', 'Average Cost Method', 'AVERAGE_COST',
 '[{"field": "weighted_average", "order": "ASC"}]',
 '{"use_weighted_average": true}',
 NULL, TRUE,
 'Use weighted average cost basis across all lots - simplified tax reporting',
 '["mutual_funds", "simplified_reporting"]',
 TRUE, 'SYSTEM', CURRENT_TIMESTAMP);

-- Sample tax lots for Apple equity swap trade
INSERT INTO TaxLot VALUES
-- Initial lot from trade execution
('LOT_001', 'TRD001', 1, 10000000.00, 8500000.00, 55401.23, 47091.05, 180.50, 9999502.19, 
 '2024-01-02', '2024-01-02 14:30:15', '2024-01-02', 'SHORT_TERM', 0.00, 'OPEN', 
 'ES001', 'EVT001', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Additional lot from trade reset/amendment
('LOT_002', 'TRD001', 2, 2000000.00, 2000000.00, 10867.94, 10867.94, 184.12, 2000145.87,
 '2024-02-15', '2024-02-15 10:45:22', '2024-02-15', 'SHORT_TERM', 0.00, 'OPEN',
 'ES007', 'EVT007', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

-- Microsoft lot from component trade
('LOT_003', 'TRD003_MSFT', 1, 700000.00, 700000.00, 1866.45, 1866.45, 375.12, 699997.94,
 '2024-01-02', '2024-01-02 14:32:22', '2024-01-02', 'SHORT_TERM', 0.00, 'OPEN',
 'ES002', 'EVT_MSFT_001', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Sample unwind record using HICO methodology
INSERT INTO TaxLotUnwind VALUES
('UNW_001', 'TRD001', 'EVT_TERM_001', 3000000.00, 16304.35, '2024-06-15', '2024-06-15 15:30:00',
 'METH_HICO', 'Client requested gain minimization for tax year', 3000000.00, 16304.35, 1,
 -45000.00, -45000.00, 0.00, 0.00, 'COMPLETED', 'Successfully unwound using highest cost lots first',
 'SYSTEM', 'TRADER001', CURRENT_TIMESTAMP, '2024-06-15 15:32:18');

-- Sample unwind detail showing lot selection
INSERT INTO TaxLotUnwindDetail VALUES
('UND_001', 'UNW_001', 'LOT_002', 2000000.00, 10867.94, 1.0000, 184.12, 2000145.87,
 182.95, 1988745.32, -11400.55, 134, 'SHORT_TERM', FALSE, 0.00, 1,
 '{"selection_reason": "Highest cost basis lot", "cost_basis": 184.12, "methodology": "HICO"}',
 182.95, '2024-06-15 15:30:45'),

('UND_002', 'UNW_001', 'LOT_001', 1000000.00, 5434.78, 0.1176, 180.50, 980970.78,
 182.95, 993899.23, 12928.45, 164, 'SHORT_TERM', FALSE, 0.00, 2, 
 '{"selection_reason": "Remaining amount from next highest cost lot", "cost_basis": 180.50, "methodology": "HICO"}',
 182.95, '2024-06-15 15:30:47');
