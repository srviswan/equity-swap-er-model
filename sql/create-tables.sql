-- Equity Swap Management System - Database Schema
-- Based on FINOS CDM Rosetta Model
-- PostgreSQL Implementation

-- =============================================================================
-- REFERENCE DATA TABLES
-- =============================================================================

-- Party table - All legal entities
CREATE TABLE Party (
    party_id VARCHAR(50) PRIMARY KEY,
    party_name VARCHAR(200) NOT NULL,
    party_type VARCHAR(20) NOT NULL CHECK (party_type IN ('BANK', 'FUND', 'CORPORATION', 'INDIVIDUAL', 'GOVERNMENT', 'OTHER')),
    lei_code CHAR(20) UNIQUE,
    party_identifiers JSONB,
    country_of_incorporation CHAR(2),
    address JSONB,
    contact_information JSONB,
    regulatory_status JSONB,
    credit_rating VARCHAR(10),
    is_active BOOLEAN DEFAULT TRUE,
    created_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Underlier table - Underlying assets (stocks, indices, baskets)
CREATE TABLE Underlier (
    underlier_id VARCHAR(50) PRIMARY KEY,
    asset_type VARCHAR(20) NOT NULL CHECK (asset_type IN ('SINGLE_NAME', 'INDEX', 'BASKET')),
    primary_identifier VARCHAR(50) NOT NULL,
    identifier_type VARCHAR(20) NOT NULL CHECK (identifier_type IN ('ISIN', 'CUSIP', 'RIC', 'BLOOMBERG', 'INTERNAL')),
    secondary_identifiers JSONB,
    asset_name VARCHAR(200) NOT NULL,
    asset_description TEXT,
    currency CHAR(3) NOT NULL,
    exchange VARCHAR(50),
    country CHAR(2),
    sector VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- BasketComponent table - Components of basket underliers
CREATE TABLE BasketComponent (
    component_id VARCHAR(50) PRIMARY KEY,
    basket_id VARCHAR(50) NOT NULL,
    component_underlier_id VARCHAR(50) NOT NULL,
    weight DECIMAL(10,6) NOT NULL CHECK (weight > 0 AND weight <= 1),
    shares DECIMAL(18,6),
    effective_date DATE NOT NULL,
    termination_date DATE,
    CONSTRAINT fk_basket_component_basket 
        FOREIGN KEY (basket_id) REFERENCES Underlier(underlier_id),
    CONSTRAINT fk_basket_component_underlier 
        FOREIGN KEY (component_underlier_id) REFERENCES Underlier(underlier_id),
    CONSTRAINT ck_basket_component_dates 
        CHECK (termination_date IS NULL OR termination_date >= effective_date),
    CONSTRAINT ck_basket_component_no_self_reference 
        CHECK (basket_id != component_underlier_id)
);

-- =============================================================================
-- PRODUCT DEFINITION TABLES
-- =============================================================================

-- TradableProduct table - Equity swap product definitions
CREATE TABLE TradableProduct (
    product_id VARCHAR(50) PRIMARY KEY,
    product_type VARCHAR(50) NOT NULL CHECK (product_type IN (
        'EQUITY_SWAP_PRICE_RETURN', 'EQUITY_SWAP_TOTAL_RETURN', 
        'EQUITY_SWAP_VARIANCE', 'EQUITY_SWAP_VOLATILITY')),
    product_name VARCHAR(200),
    asset_class VARCHAR(50) DEFAULT 'EQUITY',
    sub_asset_class VARCHAR(50) DEFAULT 'SWAP',
    version INTEGER DEFAULT 1 CHECK (version > 0),
    is_active BOOLEAN DEFAULT TRUE,
    created_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by VARCHAR(100)
);

-- EconomicTerms table - Contract terms for products
CREATE TABLE EconomicTerms (
    economic_terms_id VARCHAR(50) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    effective_date DATE NOT NULL,
    termination_date DATE,
    calculation_agent_id VARCHAR(50),
    business_day_convention VARCHAR(30) CHECK (business_day_convention IN (
        'FOLLOWING', 'MODIFIED_FOLLOWING', 'PRECEDING', 'MODIFIED_PRECEDING')),
    business_centers JSONB,
    extraordinary_events JSONB,
    version INTEGER DEFAULT 1 CHECK (version > 0),
    CONSTRAINT fk_economic_terms_product 
        FOREIGN KEY (product_id) REFERENCES TradableProduct(product_id),
    CONSTRAINT fk_economic_terms_calc_agent 
        FOREIGN KEY (calculation_agent_id) REFERENCES Party(party_id),
    CONSTRAINT ck_economic_terms_dates 
        CHECK (termination_date IS NULL OR termination_date >= effective_date)
);

-- =============================================================================
-- PAYOUT STRUCTURE TABLES
-- =============================================================================

-- Payout table - Base payout structure
CREATE TABLE Payout (
    payout_id VARCHAR(50) PRIMARY KEY,
    economic_terms_id VARCHAR(50) NOT NULL,
    payout_type VARCHAR(20) NOT NULL CHECK (payout_type IN ('PERFORMANCE', 'INTEREST_RATE', 'FIXED')),
    payer_party_id VARCHAR(50) NOT NULL,
    receiver_party_id VARCHAR(50) NOT NULL,
    payment_frequency VARCHAR(20) CHECK (payment_frequency IN (
        'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUALLY', 'ANNUALLY', 'AT_MATURITY')),
    day_count_fraction VARCHAR(10) CHECK (day_count_fraction IN ('30/360', 'ACT/360', 'ACT/365', 'ACT/ACT')),
    currency CHAR(3) NOT NULL,
    CONSTRAINT fk_payout_economic_terms 
        FOREIGN KEY (economic_terms_id) REFERENCES EconomicTerms(economic_terms_id),
    CONSTRAINT fk_payout_payer 
        FOREIGN KEY (payer_party_id) REFERENCES Party(party_id),
    CONSTRAINT fk_payout_receiver 
        FOREIGN KEY (receiver_party_id) REFERENCES Party(party_id),
    CONSTRAINT ck_payout_different_parties 
        CHECK (payer_party_id != receiver_party_id)
);

-- PerformancePayout table - Equity performance specific payouts
CREATE TABLE PerformancePayout (
    performance_payout_id VARCHAR(50) PRIMARY KEY,
    payout_id VARCHAR(50) NOT NULL UNIQUE,
    return_type VARCHAR(20) NOT NULL CHECK (return_type IN (
        'PRICE_RETURN', 'TOTAL_RETURN', 'VARIANCE_RETURN', 'VOLATILITY_RETURN')),
    initial_price DECIMAL(18,6) CHECK (initial_price > 0),
    initial_price_date DATE,
    notional_amount DECIMAL(18,2) NOT NULL CHECK (notional_amount > 0),
    notional_currency CHAR(3) NOT NULL,
    number_of_data_series INTEGER DEFAULT 1 CHECK (number_of_data_series > 0),
    observation_start_date DATE,
    observation_end_date DATE,
    valuation_time TIME,
    market_disruption_events JSONB,
    CONSTRAINT fk_performance_payout_base 
        FOREIGN KEY (payout_id) REFERENCES Payout(payout_id) ON DELETE CASCADE,
    CONSTRAINT ck_performance_observation_dates 
        CHECK (observation_end_date IS NULL OR observation_end_date >= observation_start_date)
);

-- PerformancePayoutUnderlier junction table - Links performance payouts to underliers
CREATE TABLE PerformancePayoutUnderlier (
    performance_payout_id VARCHAR(50) NOT NULL,
    underlier_id VARCHAR(50) NOT NULL,
    weight DECIMAL(10,6) DEFAULT 1.0 CHECK (weight > 0 AND weight <= 1),
    effective_date DATE NOT NULL,
    termination_date DATE,
    PRIMARY KEY (performance_payout_id, underlier_id, effective_date),
    CONSTRAINT fk_ppu_performance_payout 
        FOREIGN KEY (performance_payout_id) REFERENCES PerformancePayout(performance_payout_id),
    CONSTRAINT fk_ppu_underlier 
        FOREIGN KEY (underlier_id) REFERENCES Underlier(underlier_id),
    CONSTRAINT ck_ppu_dates 
        CHECK (termination_date IS NULL OR termination_date >= effective_date)
);

-- =============================================================================
-- TRADE TABLES
-- =============================================================================

-- Trade table - Core trade entity
CREATE TABLE Trade (
    trade_id VARCHAR(50) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    trade_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'TERMINATED', 'SUSPENDED')),
    master_agreement_id VARCHAR(50),
    confirmation_method VARCHAR(20) CHECK (confirmation_method IN ('ELECTRONIC', 'MANUAL')),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_trade_product 
        FOREIGN KEY (product_id) REFERENCES TradableProduct(product_id),
    CONSTRAINT ck_trade_date_not_future 
        CHECK (trade_date <= CURRENT_DATE)
);

-- TradeState table - Trade lifecycle states
CREATE TABLE TradeState (
    trade_state_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    state_timestamp TIMESTAMP NOT NULL,
    state_type VARCHAR(30) NOT NULL CHECK (state_type IN (
        'EXECUTION', 'RESET', 'PARTIAL_TERMINATION', 'FULL_TERMINATION', 'AMENDMENT')),
    is_current BOOLEAN DEFAULT FALSE,
    previous_state_id VARCHAR(50),
    created_by VARCHAR(100),
    CONSTRAINT fk_trade_state_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_trade_state_previous 
        FOREIGN KEY (previous_state_id) REFERENCES TradeState(trade_state_id)
);

-- PartyRole table - Roles parties play in trades
CREATE TABLE PartyRole (
    party_role_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    party_id VARCHAR(50) NOT NULL,
    role_type VARCHAR(30) NOT NULL CHECK (role_type IN (
        'COUNTERPARTY_1', 'COUNTERPARTY_2', 'CALCULATION_AGENT', 
        'PAYING_AGENT', 'DETERMINING_PARTY', 'BROKER')),
    role_description TEXT,
    effective_date DATE NOT NULL,
    termination_date DATE,
    created_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_party_role_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_party_role_party 
        FOREIGN KEY (party_id) REFERENCES Party(party_id),
    CONSTRAINT ck_party_role_dates 
        CHECK (termination_date IS NULL OR termination_date >= effective_date)
);

-- =============================================================================
-- EVENT AND LIFECYCLE TABLES
-- =============================================================================

-- TradeEvent table - Trade lifecycle events
CREATE TABLE TradeEvent (
    event_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN (
        'EXECUTION', 'CONFIRMATION', 'RESET', 'PAYMENT', 'CORPORATE_ACTION', 
        'AMENDMENT', 'PARTIAL_TERMINATION', 'FULL_TERMINATION', 'DEFAULT', 'EXTRAORDINARY_EVENT')),
    event_date DATE NOT NULL,
    effective_date DATE,
    event_qualifier VARCHAR(100),
    event_details JSONB,
    triggered_by VARCHAR(100),
    processed_by VARCHAR(100),
    processing_status VARCHAR(20) DEFAULT 'PENDING' CHECK (processing_status IN (
        'PENDING', 'PROCESSED', 'FAILED', 'CANCELLED')),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_trade_event_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE
);

-- ObservationEvent table - Underlying asset observations
CREATE TABLE ObservationEvent (
    observation_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    observation_date DATE NOT NULL,
    observation_time TIME,
    underlier_id VARCHAR(50) NOT NULL,
    observed_price DECIMAL(18,6) NOT NULL CHECK (observed_price > 0),
    observation_type VARCHAR(20) NOT NULL CHECK (observation_type IN (
        'CLOSING_PRICE', 'OPENING_PRICE', 'INTRADAY_PRICE', 'VOLUME', 'DIVIDEND')),
    source VARCHAR(100),
    market_disruption BOOLEAN DEFAULT FALSE,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_observation_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_observation_underlier 
        FOREIGN KEY (underlier_id) REFERENCES Underlier(underlier_id)
);

-- =============================================================================
-- VALUATION AND RISK TABLES
-- =============================================================================

-- Valuation table - Trade valuations
CREATE TABLE Valuation (
    valuation_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    valuation_date DATE NOT NULL,
    valuation_time TIMESTAMP,
    valuation_type VARCHAR(20) NOT NULL CHECK (valuation_type IN (
        'MARK_TO_MARKET', 'MARK_TO_MODEL', 'THIRD_PARTY')),
    base_currency CHAR(3) NOT NULL,
    market_value DECIMAL(18,2) NOT NULL,
    unrealized_pnl DECIMAL(18,2),
    daily_pnl DECIMAL(18,2),
    pv01 DECIMAL(18,6),
    delta DECIMAL(18,6),
    gamma DECIMAL(18,6),
    vega DECIMAL(18,6),
    theta DECIMAL(18,6),
    model_inputs JSONB,
    created_by VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_valuation_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE
);

-- =============================================================================
-- SETTLEMENT AND COLLATERAL TABLES
-- =============================================================================

-- Settlement table - Settlement instructions and records
CREATE TABLE Settlement (
    settlement_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    settlement_date DATE NOT NULL,
    settlement_type VARCHAR(20) NOT NULL CHECK (settlement_type IN ('CASH', 'PHYSICAL', 'NET_CASH')),
    settlement_amount DECIMAL(18,2) NOT NULL,
    settlement_currency CHAR(3) NOT NULL,
    payer_party_id VARCHAR(50) NOT NULL,
    receiver_party_id VARCHAR(50) NOT NULL,
    payment_method VARCHAR(20) CHECK (payment_method IN ('WIRE', 'ACH', 'BOOK_TRANSFER')),
    settlement_status VARCHAR(20) DEFAULT 'PENDING' CHECK (settlement_status IN (
        'PENDING', 'SETTLED', 'FAILED', 'CANCELLED')),
    settlement_reference VARCHAR(100),
    failure_reason TEXT,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settled_timestamp TIMESTAMP,
    CONSTRAINT fk_settlement_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_settlement_payer 
        FOREIGN KEY (payer_party_id) REFERENCES Party(party_id),
    CONSTRAINT fk_settlement_receiver 
        FOREIGN KEY (receiver_party_id) REFERENCES Party(party_id),
    CONSTRAINT ck_settlement_different_parties 
        CHECK (payer_party_id != receiver_party_id)
);

-- Collateral table - Collateral management
CREATE TABLE Collateral (
    collateral_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    collateral_type VARCHAR(30) NOT NULL CHECK (collateral_type IN (
        'CASH', 'GOVERNMENT_BONDS', 'CORPORATE_BONDS', 'EQUITIES', 'OTHER_SECURITIES')),
    collateral_amount DECIMAL(18,2) NOT NULL CHECK (collateral_amount > 0),
    collateral_currency CHAR(3) NOT NULL,
    posting_party_id VARCHAR(50) NOT NULL,
    receiving_party_id VARCHAR(50) NOT NULL,
    posting_date DATE NOT NULL,
    maturity_date DATE,
    haircut_percentage DECIMAL(5,2) CHECK (haircut_percentage >= 0 AND haircut_percentage <= 99.99),
    collateral_value DECIMAL(18,2) NOT NULL CHECK (collateral_value > 0),
    status VARCHAR(20) DEFAULT 'POSTED' CHECK (status IN ('POSTED', 'RETURNED', 'SUBSTITUTED')),
    custodian VARCHAR(100),
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_collateral_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE,
    CONSTRAINT fk_collateral_posting_party 
        FOREIGN KEY (posting_party_id) REFERENCES Party(party_id),
    CONSTRAINT fk_collateral_receiving_party 
        FOREIGN KEY (receiving_party_id) REFERENCES Party(party_id),
    CONSTRAINT ck_collateral_different_parties 
        CHECK (posting_party_id != receiving_party_id),
    CONSTRAINT ck_collateral_dates 
        CHECK (maturity_date IS NULL OR maturity_date >= posting_date)
);

-- =============================================================================
-- AUDIT AND DATA QUALITY TABLES
-- =============================================================================

-- DataQualityRule table - Data validation rules
CREATE TABLE DataQualityRule (
    rule_id VARCHAR(50) PRIMARY KEY,
    rule_name VARCHAR(200) NOT NULL,
    entity_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(30) NOT NULL CHECK (rule_type IN (
        'REQUIRED_FIELD', 'FORMAT_VALIDATION', 'BUSINESS_RULE', 'CROSS_REFERENCE')),
    rule_expression TEXT NOT NULL,
    error_message TEXT NOT NULL,
    severity VARCHAR(10) NOT NULL CHECK (severity IN ('ERROR', 'WARNING', 'INFO')),
    is_active BOOLEAN DEFAULT TRUE,
    created_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- AuditLog table - Comprehensive audit trail
CREATE TABLE AuditLog (
    audit_id VARCHAR(50) PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(50) NOT NULL,
    operation_type VARCHAR(10) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) NOT NULL,
    change_reason TEXT,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(100),
    ip_address VARCHAR(45)
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Primary lookup indexes
CREATE INDEX idx_trade_date ON Trade(trade_date);
CREATE INDEX idx_trade_status ON Trade(status);
CREATE INDEX idx_trade_product ON Trade(product_id);

-- Party and role indexes
CREATE INDEX idx_party_lei ON Party(lei_code);
CREATE INDEX idx_party_role_trade ON PartyRole(trade_id);
CREATE INDEX idx_party_role_party ON PartyRole(party_id);

-- Event and observation indexes
CREATE INDEX idx_trade_event_date ON TradeEvent(event_date);
CREATE INDEX idx_trade_event_type ON TradeEvent(event_type);
CREATE INDEX idx_observation_date ON ObservationEvent(observation_date);
CREATE INDEX idx_observation_underlier ON ObservationEvent(underlier_id);

-- Valuation and risk indexes
CREATE INDEX idx_valuation_date ON Valuation(valuation_date);
CREATE INDEX idx_valuation_trade ON Valuation(trade_id);

-- Settlement and collateral indexes
CREATE INDEX idx_settlement_date ON Settlement(settlement_date);
CREATE INDEX idx_settlement_status ON Settlement(settlement_status);
CREATE INDEX idx_collateral_posting_date ON Collateral(posting_date);

-- Audit indexes
CREATE INDEX idx_audit_table_record ON AuditLog(table_name, record_id);
CREATE INDEX idx_audit_timestamp ON AuditLog(change_timestamp);
CREATE INDEX idx_audit_changed_by ON AuditLog(changed_by);

-- =============================================================================
-- UNIQUE CONSTRAINTS
-- =============================================================================

-- Ensure unique current state per trade
CREATE UNIQUE INDEX idx_trade_state_current ON TradeState(trade_id) 
WHERE is_current = TRUE;

-- Ensure unique counterparty roles per trade
CREATE UNIQUE INDEX idx_party_role_counterparty1 ON PartyRole(trade_id) 
WHERE role_type = 'COUNTERPARTY_1';

CREATE UNIQUE INDEX idx_party_role_counterparty2 ON PartyRole(trade_id) 
WHERE role_type = 'COUNTERPARTY_2';

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE Trade IS 'Core equity swap trade records based on CDM specification';
COMMENT ON TABLE TradeState IS 'Tracks trade lifecycle states and transitions';
COMMENT ON TABLE TradableProduct IS 'Equity swap product definitions';
COMMENT ON TABLE EconomicTerms IS 'Contractual terms and conditions';
COMMENT ON TABLE Payout IS 'Base payout structure for all swap legs';
COMMENT ON TABLE PerformancePayout IS 'Equity performance-specific payout calculations';
COMMENT ON TABLE Party IS 'All legal entities involved in trades';
COMMENT ON TABLE Underlier IS 'Underlying assets (stocks, indices, baskets)';
COMMENT ON TABLE TradeEvent IS 'Lifecycle events throughout trade duration';
COMMENT ON TABLE Valuation IS 'Trade valuations for risk management';
COMMENT ON TABLE Settlement IS 'Settlement instructions and records';
COMMENT ON TABLE Collateral IS 'Collateral management and margin requirements';

-- Schema creation complete
SELECT 'Equity Swap Management Schema Created Successfully' AS status;
