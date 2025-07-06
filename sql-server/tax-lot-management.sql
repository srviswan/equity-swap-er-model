-- Tax Lot Management System for Equity Swaps
-- Supports various tax lot efficiency methodologies during unwinds and partial terminations
-- LIFO, FIFO, HICO (Highest Cost), LOCO (Lowest Cost), Specific ID, Average Cost
-- MS SQL Server Implementation

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
    acquisition_time DATETIME2 NOT NULL,
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
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    last_updated DATETIME2 DEFAULT GETDATE(),
    
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
    
    -- Configuration parameters (JSON format in NVARCHAR)
    sort_criteria NVARCHAR(MAX) NOT NULL, -- JSON array of sort fields and order
    selection_rules NVARCHAR(MAX), -- Additional selection logic
    
    -- Tax optimization settings
    optimize_for VARCHAR(20) CHECK (optimize_for IN (
        'MIN_GAIN', 'MAX_LOSS', 'MIN_TAX', 'LONG_TERM_PREFERRED', 'SHORT_TERM_PREFERRED')),
    wash_sale_aware BIT DEFAULT 1,
    
    -- Description and usage
    description NVARCHAR(MAX),
    applicable_scenarios NVARCHAR(MAX), -- When to use this methodology (JSON format)
    
    -- Metadata
    is_active BIT DEFAULT 1,
    created_by VARCHAR(100),
    created_timestamp DATETIME2 DEFAULT GETDATE()
);
