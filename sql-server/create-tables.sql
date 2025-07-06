-- Equity Swap Management System - Database Schema
-- Based on FINOS CDM Rosetta Model
-- MS SQL Server Implementation

-- =============================================================================
-- REFERENCE DATA TABLES
-- =============================================================================

-- Party table - All legal entities
CREATE TABLE Party (
    party_id VARCHAR(50) PRIMARY KEY,
    party_name VARCHAR(200) NOT NULL,
    party_type VARCHAR(20) NOT NULL CHECK (party_type IN ('BANK', 'FUND', 'CORPORATION', 'INDIVIDUAL', 'GOVERNMENT', 'OTHER')),
    lei_code CHAR(20) UNIQUE,
    party_identifiers NVARCHAR(MAX), -- JSON format
    country_of_incorporation CHAR(2),
    address NVARCHAR(MAX), -- JSON format
    contact_information NVARCHAR(MAX), -- JSON format
    regulatory_status NVARCHAR(MAX), -- JSON format
    credit_rating VARCHAR(10),
    is_active BIT DEFAULT 1,
    created_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    last_updated DATETIME2 DEFAULT GETDATE()
);

-- Underlier table - Underlying assets (stocks, indices, baskets)
CREATE TABLE Underlier (
    underlier_id VARCHAR(50) PRIMARY KEY,
    asset_type VARCHAR(20) NOT NULL CHECK (asset_type IN ('SINGLE_NAME', 'INDEX', 'BASKET')),
    primary_identifier VARCHAR(50) NOT NULL,
    identifier_type VARCHAR(20) NOT NULL CHECK (identifier_type IN ('ISIN', 'CUSIP', 'RIC', 'BLOOMBERG', 'INTERNAL')),
    secondary_identifiers NVARCHAR(MAX), -- JSON format
    asset_name VARCHAR(200) NOT NULL,
    asset_description NVARCHAR(MAX),
    currency CHAR(3) NOT NULL,
    exchange VARCHAR(50),
    country CHAR(2),
    sector VARCHAR(100),
    is_active BIT DEFAULT 1,
    created_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    last_updated DATETIME2 DEFAULT GETDATE()
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
    is_active BIT DEFAULT 1,
    created_date DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
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
    business_centers NVARCHAR(MAX), -- JSON format
    extraordinary_events NVARCHAR(MAX), -- JSON format
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
    settlement_currency CHAR(3),
    fx_reset_required BIT DEFAULT 0,
    fx_reset_frequency VARCHAR(20) CHECK (fx_reset_frequency IN (
        'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUALLY', 'ANNUALLY', 'AT_PAYMENT')),
    fx_rate_source VARCHAR(100),
    fx_fixing_time TIME,
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
    market_disruption_events NVARCHAR(MAX), -- JSON format
    CONSTRAINT fk_performance_payout_base 
        FOREIGN KEY (payout_id) REFERENCES Payout(payout_id) ON DELETE CASCADE,
    CONSTRAINT ck_performance_observation_dates 
        CHECK (observation_end_date IS NULL OR observation_end_date >= observation_start_date)
);

-- Trade table - Core trade entity
CREATE TABLE Trade (
    trade_id VARCHAR(50) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    trade_date DATE NOT NULL,
    trade_time DATETIME2,
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'TERMINATED', 'SUSPENDED')),
    master_agreement_id VARCHAR(50),
    confirmation_method VARCHAR(20) CHECK (confirmation_method IN ('ELECTRONIC', 'MANUAL')),
    created_timestamp DATETIME2 DEFAULT GETDATE(),
    updated_timestamp DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT fk_trade_product 
        FOREIGN KEY (product_id) REFERENCES TradableProduct(product_id),
    CONSTRAINT ck_trade_date_not_future 
        CHECK (trade_date <= CAST(GETDATE() AS DATE))
);

-- Complete schema creation message
SELECT 'Equity Swap Management Schema (SQL Server) - Core Tables Created Successfully' AS status;
