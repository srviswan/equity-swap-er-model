-- Sample Data for Equity Swap Management System (MS SQL Server)
-- This script demonstrates typical equity swap scenarios
-- Converted from PostgreSQL to MS SQL Server syntax

-- =============================================================================
-- REFERENCE DATA - PARTIES
-- =============================================================================

-- Insert sample parties
INSERT INTO Party (party_id, party_name, party_type, lei_code, country_of_incorporation, is_active) VALUES
('PARTY001', 'Goldman Sachs International', 'BANK', 'W22LROWP2IHZNBB6K528', 'GB', 1),
('PARTY002', 'BlackRock Global Funds', 'FUND', '549300MS535GM1PT2B86', 'LU', 1),
('PARTY003', 'Vanguard Asset Management', 'FUND', '549300YVMJ9OGU3HLM41', 'US', 1),
('PARTY004', 'JPMorgan Chase Bank', 'BANK', '7H6GLXDRUGQFU57RNE97', 'US', 1),
('PARTY005', 'Deutsche Bank AG', 'BANK', '7LTWFZYICNSX8D621K86', 'DE', 1);

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
('PROD003', 'EQUITY_SWAP_VARIANCE', 'Equity Variance Swap', '2024-01-01', 'SYSTEM'),
('PROD004', 'EQUITY_SWAP_VOLATILITY', 'Equity Volatility Swap', '2024-01-01', 'SYSTEM');

-- =============================================================================
-- COUNTERPARTY ROLES
-- =============================================================================

-- Define counterparty roles for each product
INSERT INTO CounterpartyRole (counterparty_role_id, product_id, party_id, role_type, role_qualifier) VALUES
('CR001', 'PROD001', 'PARTY001', 'DEALER', 'EQUITY_RETURN_PAYER'),
('CR002', 'PROD001', 'PARTY002', 'CLIENT', 'EQUITY_RETURN_RECEIVER'),
('CR003', 'PROD002', 'PARTY004', 'DEALER', 'EQUITY_RETURN_PAYER'),
('CR004', 'PROD002', 'PARTY003', 'CLIENT', 'EQUITY_RETURN_RECEIVER'),
('CR005', 'PROD003', 'PARTY005', 'DEALER', 'VARIANCE_PAYER'),
('CR006', 'PROD003', 'PARTY002', 'CLIENT', 'VARIANCE_RECEIVER');

-- =============================================================================
-- PAYOUTS - EQUITY PERFORMANCE
-- =============================================================================

-- Sample performance payouts for different swap types
INSERT INTO Payout (payout_id, product_id, payer_party_id, receiver_party_id, payout_type, payout_currency, payout_frequency, created_date) VALUES
('PAY001', 'PROD001', 'PARTY001', 'PARTY002', 'EQUITY_PERFORMANCE', 'USD', 'QUARTERLY', '2024-01-01'),
('PAY002', 'PROD002', 'PARTY004', 'PARTY003', 'EQUITY_PERFORMANCE', 'USD', 'MONTHLY', '2024-01-01'),
('PAY003', 'PROD003', 'PARTY005', 'PARTY002', 'VARIANCE_PERFORMANCE', 'USD', 'MATURITY', '2024-01-01');

-- Performance payout details
INSERT INTO PerformancePayout (performance_payout_id, payout_id, return_type, initial_price, initial_price_date, notional_amount, notional_currency, observation_start_date, observation_end_date) VALUES
('PP001', 'PAY001', 'TOTAL_RETURN', 180.50, '2024-01-02', 10000000.00, 'USD', '2024-01-02', '2024-12-31'),
('PP002', 'PAY002', 'PRICE_RETURN', 420.25, '2024-01-02', 5000000.00, 'USD', '2024-01-02', '2024-06-30'),
('PP003', 'PAY003', 'VARIANCE_RETURN', NULL, NULL, 1000000.00, 'USD', '2024-01-02', '2024-03-31');

-- =============================================================================
-- TRADE EXECUTION
-- =============================================================================

-- Sample trades
INSERT INTO Trade (trade_id, product_id, trade_date, trade_time, status, confirmation_method) VALUES
('TRD001', 'PROD001', '2024-01-02', '2024-01-02 10:30:00', 'ACTIVE', 'ELECTRONIC'),
('TRD002', 'PROD002', '2024-01-03', '2024-01-03 14:15:00', 'ACTIVE', 'ELECTRONIC'),
('TRD003', 'PROD003', '2024-01-05', '2024-01-05 09:45:00', 'ACTIVE', 'MANUAL');

-- =============================================================================
-- FX RATES (for cross-currency examples)
-- =============================================================================

-- Sample FX rates for EUR/USD and GBP/USD
INSERT INTO FXRate (fx_rate_id, base_currency, quote_currency, rate_value, rate_date, rate_time, rate_type, rate_source) VALUES
('FX001', 'EUR', 'USD', 1.0850, CAST(GETDATE() AS DATE), '16:00:00', 'SPOT', 'WM_REUTERS'),
('FX002', 'GBP', 'USD', 1.2650, CAST(GETDATE() AS DATE), '16:00:00', 'SPOT', 'WM_REUTERS'),
('FX003', 'USD', 'JPY', 150.25, CAST(GETDATE() AS DATE), '16:00:00', 'SPOT', 'WM_REUTERS');

-- Currency pair definitions
INSERT INTO CurrencyPair (pair_id, base_currency, quote_currency, market_convention, trading_start_time, trading_end_time, settlement_days) VALUES
('EURUSD', 'EUR', 'USD', 'EUR/USD', '07:00:00', '17:00:00', 2),
('GBPUSD', 'GBP', 'USD', 'GBP/USD', '07:00:00', '17:00:00', 2),
('USDJPY', 'USD', 'JPY', 'USD/JPY', '07:00:00', '17:00:00', 2);

-- =============================================================================
-- TAX LOT SAMPLE DATA
-- =============================================================================

-- Sample tax lots for trade TRD001
INSERT INTO TaxLot (tax_lot_id, trade_id, lot_number, acquisition_date, cost_basis, quantity, lot_status, holding_period_type) VALUES
('TL001', 'TRD001', 1, '2024-01-02', 180.50, 10000.00, 'OPEN', 'SHORT_TERM'),
('TL002', 'TRD001', 2, '2024-02-15', 185.25, 5000.00, 'OPEN', 'SHORT_TERM'),
('TL003', 'TRD001', 3, '2024-03-01', 192.75, 8000.00, 'OPEN', 'SHORT_TERM');

-- Tax lot unwind methodologies
INSERT INTO TaxLotUnwindMethodology (methodology_id, methodology_name, methodology_type, sort_criteria, is_active) VALUES
('METH001', 'Last In First Out', 'LIFO', '{"sort_field": "acquisition_date", "sort_order": "DESC"}', 1),
('METH002', 'First In First Out', 'FIFO', '{"sort_field": "acquisition_date", "sort_order": "ASC"}', 1),
('METH003', 'Highest Cost First', 'HICO', '{"sort_field": "cost_basis", "sort_order": "DESC"}', 1),
('METH004', 'Lowest Cost First', 'LOCO', '{"sort_field": "cost_basis", "sort_order": "ASC"}', 1);

-- =============================================================================
-- TRADE GROUPS AND BASKET RELATIONSHIPS
-- =============================================================================

-- Sample trade group for basket strategy
INSERT INTO TradeGroup (group_id, group_name, group_type, strategy_description, group_status, target_total_notional, target_currency, created_by) VALUES
('GRP001', 'Tech Sector Basket Q1 2024', 'BASKET_STRATEGY', 'Long technology sector exposure through component trades', 'ACTIVE', 15000000.00, 'USD', 'TRADER_001');

-- Trade group members (assuming individual component trades exist)
INSERT INTO TradeGroupMember (group_member_id, group_id, trade_id, member_role, target_weight, actual_weight, execution_sequence, is_required, fill_status) VALUES
('TGM001', 'GRP001', 'TRD001', 'BASKET_COMPONENT', 0.40, 0.38, 1, 1, 'FILLED'),
('TGM002', 'GRP001', 'TRD002', 'BASKET_COMPONENT', 0.35, 0.36, 2, 1, 'FILLED'),
('TGM003', 'GRP001', 'TRD003', 'BASKET_COMPONENT', 0.25, 0.26, 3, 1, 'FILLED');

-- =============================================================================
-- VALUATION DATA
-- =============================================================================

-- Sample valuations for active trades
INSERT INTO Valuation (valuation_id, trade_id, valuation_date, market_value, unrealized_pnl, valuation_currency, price_source, created_timestamp) VALUES
('VAL001', 'TRD001', CAST(GETDATE() AS DATE), 11250000.00, 250000.00, 'USD', 'BLOOMBERG', GETDATE()),
('VAL002', 'TRD002', CAST(GETDATE() AS DATE), 5125000.00, 125000.00, 'USD', 'REUTERS', GETDATE()),
('VAL003', 'TRD003', CAST(GETDATE() AS DATE), 1050000.00, 50000.00, 'USD', 'INTERNAL', GETDATE());

-- =============================================================================
-- OPERATIONAL WORKFLOW DATA
-- =============================================================================

-- Sample workflow definitions
INSERT INTO WorkflowDefinition (workflow_id, workflow_name, workflow_type, trigger_event, workflow_steps, is_active) VALUES
('WF001', 'Trade Booking Workflow', 'TRADE_LIFECYCLE', 'TRADE_EXECUTED', '{"steps": ["TRADE_CAPTURE", "RISK_CHECK", "SETTLEMENT_INSTRUCTION", "CONFIRMATION"]}', 1),
('WF002', 'Daily Valuation Workflow', 'VALUATION', 'SCHEDULED_DAILY', '{"steps": ["PRICE_FETCH", "MTM_CALCULATION", "PNL_CALCULATION", "REPORTING"]}', 1);

-- Sample workflow instances
INSERT INTO WorkflowInstance (instance_id, workflow_id, entity_id, entity_type, instance_status, started_timestamp) VALUES
('WI001', 'WF001', 'TRD001', 'TRADE', 'COMPLETED', GETDATE()),
('WI002', 'WF002', 'TRD001', 'TRADE', 'IN_PROGRESS', GETDATE());

-- =============================================================================
-- COMPLETION MESSAGE
-- =============================================================================

SELECT 'Sample data loaded successfully for Equity Swap Management System (SQL Server)' AS status,
       'Data includes parties, underliers, products, trades, tax lots, and operational workflows' AS description;
