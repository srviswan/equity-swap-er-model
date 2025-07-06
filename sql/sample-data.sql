-- Sample Data for Equity Swap Management System
-- This script demonstrates typical equity swap scenarios

-- =============================================================================
-- REFERENCE DATA - PARTIES
-- =============================================================================

-- Insert sample parties
INSERT INTO Party (party_id, party_name, party_type, lei_code, country_of_incorporation, is_active) VALUES
('PARTY001', 'Goldman Sachs International', 'BANK', 'W22LROWP2IHZNBB6K528', 'GB', TRUE),
('PARTY002', 'BlackRock Global Funds', 'FUND', '549300MS535GM1PT2B86', 'LU', TRUE),
('PARTY003', 'Vanguard Asset Management', 'FUND', '549300YVMJ9OGU3HLM41', 'US', TRUE),
('PARTY004', 'JPMorgan Chase Bank', 'BANK', '7H6GLXDRUGQFU57RNE97', 'US', TRUE),
('PARTY005', 'Deutsche Bank AG', 'BANK', '7LTWFZYICNSX8D621K86', 'DE', TRUE);

-- =============================================================================
-- REFERENCE DATA - UNDERLIERS
-- =============================================================================

-- Single name stocks
INSERT INTO Underlier (underlier_id, asset_type, primary_identifier, identifier_type, asset_name, currency, exchange, country, sector) VALUES
('UND001', 'SINGLE_NAME', 'US0378331005', 'ISIN', 'Apple Inc', 'USD', 'NASDAQ', 'US', 'Technology'),
('UND002', 'SINGLE_NAME', 'US5949181045', 'ISIN', 'Microsoft Corporation', 'USD', 'NASDAQ', 'US', 'Technology'),
('UND003', 'SINGLE_NAME', 'US02079K3059', 'ISIN', 'Alphabet Inc Class A', 'USD', 'NASDAQ', 'US', 'Technology'),
('UND004', 'SINGLE_NAME', 'US88160R1014', 'ISIN', 'Tesla Inc', 'USD', 'NASDAQ', 'US', 'Automotive'),
('UND005', 'SINGLE_NAME', 'NL0000235190', 'ISIN', 'Airbus SE', 'EUR', 'EPA', 'NL', 'Aerospace');

-- Index underliers
INSERT INTO Underlier (underlier_id, asset_type, primary_identifier, identifier_type, asset_name, currency, exchange, country, sector) VALUES
('UND006', 'INDEX', 'US78378X1072', 'ISIN', 'S&P 500 Index', 'USD', 'NYSE', 'US', 'Diversified'),
('UND007', 'INDEX', 'US6311011026', 'ISIN', 'NASDAQ-100 Index', 'USD', 'NASDAQ', 'US', 'Technology'),
('UND008', 'INDEX', 'EU0009658145', 'ISIN', 'EURO STOXX 50', 'EUR', 'XETR', 'EU', 'Diversified');

-- Basket underlier
INSERT INTO Underlier (underlier_id, asset_type, primary_identifier, identifier_type, asset_name, currency, exchange, country, sector) VALUES
('UND009', 'BASKET', 'TECH_BASKET_001', 'INTERNAL', 'Technology Basket', 'USD', 'COMPOSITE', 'US', 'Technology');

-- Basket components
INSERT INTO BasketComponent (component_id, basket_id, component_underlier_id, weight, effective_date) VALUES
('BC001', 'UND009', 'UND001', 0.40, '2024-01-01'), -- Apple 40%
('BC002', 'UND009', 'UND002', 0.35, '2024-01-01'), -- Microsoft 35%
('BC003', 'UND009', 'UND003', 0.25, '2024-01-01'); -- Alphabet 25%

-- =============================================================================
-- PRODUCT DEFINITIONS
-- =============================================================================

-- Equity swap products
INSERT INTO TradableProduct (product_id, product_type, product_name, created_date, created_by) VALUES
('PROD001', 'EQUITY_SWAP_TOTAL_RETURN', 'Equity Total Return Swap', '2024-01-01', 'SYSTEM'),
('PROD002', 'EQUITY_SWAP_PRICE_RETURN', 'Equity Price Return Swap', '2024-01-01', 'SYSTEM'),
('PROD003', 'EQUITY_SWAP_VARIANCE', 'Equity Variance Swap', '2024-01-01', 'SYSTEM');

-- Economic terms
INSERT INTO EconomicTerms (economic_terms_id, product_id, effective_date, termination_date, calculation_agent_id, business_day_convention) VALUES
('ET001', 'PROD001', '2024-01-01', '2025-01-01', 'PARTY001', 'MODIFIED_FOLLOWING'),
('ET002', 'PROD002', '2024-01-01', '2024-12-31', 'PARTY004', 'FOLLOWING'),
('ET003', 'PROD003', '2024-01-01', '2024-06-30', 'PARTY005', 'MODIFIED_FOLLOWING');

-- =============================================================================
-- PAYOUT STRUCTURES
-- =============================================================================

-- Base payouts
INSERT INTO Payout (payout_id, economic_terms_id, payout_type, payer_party_id, receiver_party_id, payment_frequency, currency) VALUES
('PAY001', 'ET001', 'PERFORMANCE', 'PARTY001', 'PARTY002', 'QUARTERLY', 'USD'),
('PAY002', 'ET001', 'INTEREST_RATE', 'PARTY002', 'PARTY001', 'QUARTERLY', 'USD'),
('PAY003', 'ET002', 'PERFORMANCE', 'PARTY004', 'PARTY003', 'MONTHLY', 'USD'),
('PAY004', 'ET003', 'PERFORMANCE', 'PARTY005', 'PARTY002', 'AT_MATURITY', 'USD');

-- Performance payouts
INSERT INTO PerformancePayout (performance_payout_id, payout_id, return_type, initial_price, initial_price_date, notional_amount, notional_currency, observation_start_date, observation_end_date) VALUES
('PP001', 'PAY001', 'TOTAL_RETURN', 180.50, '2024-01-02', 10000000.00, 'USD', '2024-01-02', '2025-01-01'),
('PP002', 'PAY003', 'PRICE_RETURN', 4500.25, '2024-01-02', 5000000.00, 'USD', '2024-01-02', '2024-12-31'),
('PP003', 'PAY004', 'VARIANCE_RETURN', 25.50, '2024-01-02', 2000000.00, 'USD', '2024-01-02', '2024-06-30');

-- Link performance payouts to underliers
INSERT INTO PerformancePayoutUnderlier (performance_payout_id, underlier_id, weight, effective_date) VALUES
('PP001', 'UND001', 1.0, '2024-01-02'), -- Apple total return swap
('PP002', 'UND006', 1.0, '2024-01-02'), -- S&P 500 price return swap
('PP003', 'UND007', 1.0, '2024-01-02'); -- NASDAQ-100 variance swap

-- =============================================================================
-- TRADES
-- =============================================================================

-- Sample trades
INSERT INTO Trade (trade_id, product_id, trade_date, trade_time, status, confirmation_method) VALUES
('TRD001', 'PROD001', '2024-01-02', '2024-01-02 14:30:00', 'ACTIVE', 'ELECTRONIC'),
('TRD002', 'PROD002', '2024-01-02', '2024-01-02 15:45:00', 'ACTIVE', 'ELECTRONIC'),
('TRD003', 'PROD003', '2024-01-02', '2024-01-02 16:20:00', 'ACTIVE', 'MANUAL');

-- Trade states (initial execution states)
INSERT INTO TradeState (trade_state_id, trade_id, state_timestamp, state_type, is_current, created_by) VALUES
('TS001', 'TRD001', '2024-01-02 14:30:00', 'EXECUTION', TRUE, 'TRADER001'),
('TS002', 'TRD002', '2024-01-02 15:45:00', 'EXECUTION', TRUE, 'TRADER002'),
('TS003', 'TRD003', '2024-01-02 16:20:00', 'EXECUTION', TRUE, 'TRADER003');

-- Party roles in trades
INSERT INTO PartyRole (party_role_id, trade_id, party_id, role_type, effective_date, created_by) VALUES
-- Trade 1: Goldman Sachs vs BlackRock
('PR001', 'TRD001', 'PARTY001', 'COUNTERPARTY_1', '2024-01-02', 'SYSTEM'),
('PR002', 'TRD001', 'PARTY002', 'COUNTERPARTY_2', '2024-01-02', 'SYSTEM'),
('PR003', 'TRD001', 'PARTY001', 'CALCULATION_AGENT', '2024-01-02', 'SYSTEM'),

-- Trade 2: JPMorgan vs Vanguard
('PR004', 'TRD002', 'PARTY004', 'COUNTERPARTY_1', '2024-01-02', 'SYSTEM'),
('PR005', 'TRD002', 'PARTY003', 'COUNTERPARTY_2', '2024-01-02', 'SYSTEM'),
('PR006', 'TRD002', 'PARTY004', 'CALCULATION_AGENT', '2024-01-02', 'SYSTEM'),

-- Trade 3: Deutsche Bank vs BlackRock
('PR007', 'TRD003', 'PARTY005', 'COUNTERPARTY_1', '2024-01-02', 'SYSTEM'),
('PR008', 'TRD003', 'PARTY002', 'COUNTERPARTY_2', '2024-01-02', 'SYSTEM'),
('PR009', 'TRD003', 'PARTY005', 'CALCULATION_AGENT', '2024-01-02', 'SYSTEM');

-- =============================================================================
-- TRADE EVENTS
-- =============================================================================

-- Initial execution events
INSERT INTO TradeEvent (event_id, trade_id, event_type, event_date, event_qualifier, processing_status, processed_by) VALUES
('EVT001', 'TRD001', 'EXECUTION', '2024-01-02', 'TradeExecution', 'PROCESSED', 'SYSTEM'),
('EVT002', 'TRD002', 'EXECUTION', '2024-01-02', 'TradeExecution', 'PROCESSED', 'SYSTEM'),
('EVT003', 'TRD003', 'EXECUTION', '2024-01-02', 'TradeExecution', 'PROCESSED', 'SYSTEM');

-- Confirmation events
INSERT INTO TradeEvent (event_id, trade_id, event_type, event_date, effective_date, event_qualifier, processing_status, processed_by) VALUES
('EVT004', 'TRD001', 'CONFIRMATION', '2024-01-03', '2024-01-02', 'TradeConfirmation', 'PROCESSED', 'SYSTEM'),
('EVT005', 'TRD002', 'CONFIRMATION', '2024-01-03', '2024-01-02', 'TradeConfirmation', 'PROCESSED', 'SYSTEM'),
('EVT006', 'TRD003', 'CONFIRMATION', '2024-01-04', '2024-01-02', 'TradeConfirmation', 'PROCESSED', 'SYSTEM');

-- Sample reset event
INSERT INTO TradeEvent (event_id, trade_id, event_type, event_date, effective_date, event_qualifier, processing_status, processed_by) VALUES
('EVT007', 'TRD002', 'RESET', '2024-02-01', '2024-02-01', 'PerformanceReset', 'PROCESSED', 'SYSTEM');

-- =============================================================================
-- OBSERVATION EVENTS
-- =============================================================================

-- Sample price observations for Apple (first few days)
INSERT INTO ObservationEvent (observation_id, trade_id, observation_date, observation_time, underlier_id, observed_price, observation_type, source) VALUES
('OBS001', 'TRD001', '2024-01-02', '16:00:00', 'UND001', 180.50, 'CLOSING_PRICE', 'NASDAQ'),
('OBS002', 'TRD001', '2024-01-03', '16:00:00', 'UND001', 182.25, 'CLOSING_PRICE', 'NASDAQ'),
('OBS003', 'TRD001', '2024-01-04', '16:00:00', 'UND001', 179.80, 'CLOSING_PRICE', 'NASDAQ'),
('OBS004', 'TRD001', '2024-01-05', '16:00:00', 'UND001', 184.30, 'CLOSING_PRICE', 'NASDAQ');

-- Sample dividend observation
INSERT INTO ObservationEvent (observation_id, trade_id, observation_date, observation_time, underlier_id, observed_price, observation_type, source) VALUES
('OBS005', 'TRD001', '2024-02-15', '09:00:00', 'UND001', 0.24, 'DIVIDEND', 'NASDAQ');

-- Sample S&P 500 observations
INSERT INTO ObservationEvent (observation_id, trade_id, observation_date, observation_time, underlier_id, observed_price, observation_type, source) VALUES
('OBS006', 'TRD002', '2024-01-02', '16:00:00', 'UND006', 4500.25, 'CLOSING_PRICE', 'NYSE'),
('OBS007', 'TRD002', '2024-01-03', '16:00:00', 'UND006', 4515.80, 'CLOSING_PRICE', 'NYSE'),
('OBS008', 'TRD002', '2024-01-04', '16:00:00', 'UND006', 4498.60, 'CLOSING_PRICE', 'NYSE');

-- =============================================================================
-- VALUATIONS
-- =============================================================================

-- Sample daily valuations
INSERT INTO Valuation (valuation_id, trade_id, valuation_date, valuation_type, base_currency, market_value, unrealized_pnl, daily_pnl, delta, created_by) VALUES
('VAL001', 'TRD001', '2024-01-02', 'MARK_TO_MARKET', 'USD', 10000000.00, 0.00, 0.00, 1.0, 'RISK_SYSTEM'),
('VAL002', 'TRD001', '2024-01-03', 'MARK_TO_MARKET', 'USD', 10096984.00, 96984.00, 96984.00, 1.0, 'RISK_SYSTEM'),
('VAL003', 'TRD001', '2024-01-04', 'MARK_TO_MARKET', 'USD', 9963536.00, -36464.00, -133448.00, 1.0, 'RISK_SYSTEM'),
('VAL004', 'TRD001', '2024-01-05', 'MARK_TO_MARKET', 'USD', 10213298.00, 213298.00, 249762.00, 1.0, 'RISK_SYSTEM');

INSERT INTO Valuation (valuation_id, trade_id, valuation_date, valuation_type, base_currency, market_value, unrealized_pnl, daily_pnl, delta, created_by) VALUES
('VAL005', 'TRD002', '2024-01-02', 'MARK_TO_MARKET', 'USD', 5000000.00, 0.00, 0.00, 1.0, 'RISK_SYSTEM'),
('VAL006', 'TRD002', '2024-01-03', 'MARK_TO_MARKET', 'USD', 5017322.00, 17322.00, 17322.00, 1.0, 'RISK_SYSTEM'),
('VAL007', 'TRD002', '2024-01-04', 'MARK_TO_MARKET', 'USD', 4998134.00, -1866.00, -19188.00, 1.0, 'RISK_SYSTEM');

-- =============================================================================
-- SETTLEMENTS
-- =============================================================================

-- Sample settlement for dividend payment
INSERT INTO Settlement (settlement_id, trade_id, settlement_date, settlement_type, settlement_amount, settlement_currency, payer_party_id, receiver_party_id, payment_method, settlement_status) VALUES
('SET001', 'TRD001', '2024-02-20', 'CASH', 13307.20, 'USD', 'PARTY001', 'PARTY002', 'WIRE', 'SETTLED');

-- Quarterly reset settlement
INSERT INTO Settlement (settlement_id, trade_id, settlement_date, settlement_type, settlement_amount, settlement_currency, payer_party_id, receiver_party_id, payment_method, settlement_status) VALUES
('SET002', 'TRD002', '2024-04-01', 'NET_CASH', 245680.00, 'USD', 'PARTY003', 'PARTY004', 'BOOK_TRANSFER', 'PENDING');

-- =============================================================================
-- COLLATERAL
-- =============================================================================

-- Sample collateral postings
INSERT INTO Collateral (collateral_id, trade_id, collateral_type, collateral_amount, collateral_currency, posting_party_id, receiving_party_id, posting_date, haircut_percentage, collateral_value, custodian) VALUES
('COL001', 'TRD001', 'CASH', 500000.00, 'USD', 'PARTY002', 'PARTY001', '2024-01-02', 0.00, 500000.00, 'BNY Mellon'),
('COL002', 'TRD002', 'GOVERNMENT_BONDS', 300000.00, 'USD', 'PARTY003', 'PARTY004', '2024-01-02', 2.00, 294000.00, 'State Street'),
('COL003', 'TRD003', 'CASH', 150000.00, 'USD', 'PARTY002', 'PARTY005', '2024-01-02', 0.00, 150000.00, 'JPMorgan Chase');

-- =============================================================================
-- DATA QUALITY RULES
-- =============================================================================

-- Sample data quality rules
INSERT INTO DataQualityRule (rule_id, rule_name, entity_name, rule_type, rule_expression, error_message, severity) VALUES
('DQR001', 'Trade Date Not Future', 'Trade', 'BUSINESS_RULE', 'trade_date <= CURRENT_DATE', 'Trade date cannot be in the future', 'ERROR'),
('DQR002', 'Positive Notional Amount', 'PerformancePayout', 'BUSINESS_RULE', 'notional_amount > 0', 'Notional amount must be positive', 'ERROR'),
('DQR003', 'Valid Currency Code', 'Payout', 'FORMAT_VALIDATION', 'LENGTH(currency) = 3', 'Currency code must be 3 characters', 'ERROR'),
('DQR004', 'LEI Code Format', 'Party', 'FORMAT_VALIDATION', 'lei_code ~ ''^[A-Z0-9]{18}[0-9]{2}$''', 'LEI code must be 20 characters (18 alphanumeric + 2 digits)', 'WARNING'),
('DQR005', 'Basket Weights Sum', 'BasketComponent', 'BUSINESS_RULE', 'SUM(weight) = 1.0 GROUP BY basket_id, effective_date', 'Basket component weights must sum to 1.0', 'ERROR');

-- =============================================================================
-- SAMPLE AUDIT LOG ENTRIES
-- =============================================================================

-- Sample audit log entries
INSERT INTO AuditLog (audit_id, table_name, record_id, operation_type, new_values, changed_by, change_reason, session_id) VALUES
('AUD001', 'Trade', 'TRD001', 'INSERT', '{"trade_id":"TRD001","product_id":"PROD001","trade_date":"2024-01-02","status":"ACTIVE"}', 'TRADER001', 'New trade execution', 'SESSION_12345'),
('AUD002', 'TradeState', 'TS001', 'INSERT', '{"trade_state_id":"TS001","trade_id":"TRD001","state_type":"EXECUTION","is_current":true}', 'SYSTEM', 'Initial trade state', 'SESSION_12345'),
('AUD003', 'Valuation', 'VAL001', 'INSERT', '{"valuation_id":"VAL001","trade_id":"TRD001","market_value":10000000.00,"valuation_date":"2024-01-02"}', 'RISK_SYSTEM', 'Initial valuation', 'SESSION_67890');

-- =============================================================================
-- SAMPLE QUERIES TO VERIFY DATA
-- =============================================================================

-- Query to show trade summary
SELECT 
    t.trade_id,
    t.trade_date,
    p.product_name,
    t.status,
    p1.party_name as counterparty_1,
    p2.party_name as counterparty_2,
    pp.return_type,
    pp.notional_amount,
    pp.notional_currency,
    u.asset_name as underlying
FROM Trade t
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
JOIN PartyRole pr1 ON t.trade_id = pr1.trade_id AND pr1.role_type = 'COUNTERPARTY_1'
JOIN Party p1 ON pr1.party_id = p1.party_id
JOIN PartyRole pr2 ON t.trade_id = pr2.trade_id AND pr2.role_type = 'COUNTERPARTY_2'
JOIN Party p2 ON pr2.party_id = p2.party_id;

-- Query to show latest valuations
SELECT 
    t.trade_id,
    v.valuation_date,
    v.market_value,
    v.unrealized_pnl,
    v.daily_pnl,
    u.asset_name
FROM Trade t
JOIN Valuation v ON t.trade_id = v.trade_id
JOIN TradableProduct tp ON t.product_id = tp.product_id
JOIN EconomicTerms et ON tp.product_id = et.product_id
JOIN Payout p ON et.economic_terms_id = p.economic_terms_id
JOIN PerformancePayout pp ON p.payout_id = pp.payout_id
JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
JOIN Underlier u ON ppu.underlier_id = u.underlier_id
WHERE v.valuation_date = (
    SELECT MAX(valuation_date) 
    FROM Valuation v2 
    WHERE v2.trade_id = t.trade_id
)
ORDER BY t.trade_id;

SELECT 'Sample data loaded successfully. ' || COUNT(*) || ' trades created.' as status
FROM Trade;
