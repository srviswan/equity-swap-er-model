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
-- CROSS-CURRENCY SAMPLE DATA
-- =============================================================================

-- Currency Pair Sample Data
INSERT INTO CurrencyPair (currency_pair_id, base_currency, quote_currency, pair_code, market_convention, spot_days, tick_size, is_active, created_date) VALUES
('EURUSD-PAIR', 'EUR', 'USD', 'EURUSD', 'London 4PM Fix', 2, 0.00001, TRUE, '2024-01-01'),
('USDJPY-PAIR', 'USD', 'JPY', 'USDJPY', 'Tokyo 3PM Fix', 2, 0.001, TRUE, '2024-01-01'),
('GBPUSD-PAIR', 'GBP', 'USD', 'GBPUSD', 'London 4PM Fix', 2, 0.00001, TRUE, '2024-01-01'),
('USDCHF-PAIR', 'USD', 'CHF', 'USDCHF', 'Zurich Close', 2, 0.00001, TRUE, '2024-01-01');

-- FX Rate Sample Data
INSERT INTO FXRate (fx_rate_id, base_currency, quote_currency, rate_date, rate_time, rate_value, rate_source, rate_type, is_active, created_date) VALUES
('EUR-USD-20240115', 'EUR', 'USD', '2024-01-15', '16:00:00', 1.0890, 'WM/Reuters', 'FIXING', TRUE, '2024-01-15'),
('USD-JPY-20240115', 'USD', 'JPY', '2024-01-15', '15:00:00', 148.50, 'WM/Reuters', 'FIXING', TRUE, '2024-01-15'),
('GBP-USD-20240115', 'GBP', 'USD', '2024-01-15', '16:00:00', 1.2750, 'WM/Reuters', 'FIXING', TRUE, '2024-01-15'),
('EUR-USD-20240415', 'EUR', 'USD', '2024-04-15', '16:00:00', 1.0745, 'WM/Reuters', 'FIXING', TRUE, '2024-04-15'),
('USD-JPY-20240415', 'USD', 'JPY', '2024-04-15', '15:00:00', 150.25, 'WM/Reuters', 'FIXING', TRUE, '2024-04-15'),
('GBP-USD-20240415', 'GBP', 'USD', '2024-04-15', '16:00:00', 1.2580, 'WM/Reuters', 'FIXING', TRUE, '2024-04-15');

-- FX Reset Event Sample Data
INSERT INTO FXResetEvent (fx_reset_id, trade_id, payout_id, reset_date, reset_time, base_currency, quote_currency, fx_rate, fx_rate_source, reset_type, reset_status, payment_date, created_date) VALUES
('FX-RST-001', 'EQS-APPL-001', 'EQUITY-LEG-001', '2024-04-15', '16:00:00', 'EUR', 'USD', 1.0745, 'WM/Reuters', 'PERIODIC', 'FIXED', '2024-04-17', '2024-04-15'),
('FX-RST-002', 'EQS-NIKKEI-001', 'EQUITY-LEG-002', '2024-04-15', '15:00:00', 'USD', 'JPY', 150.25, 'WM/Reuters', 'PERIODIC', 'FIXED', '2024-04-17', '2024-04-15'),
('FX-RST-003', 'EQS-APPL-001', 'EQUITY-LEG-001', '2024-07-15', '16:00:00', 'EUR', 'USD', 1.0820, 'WM/Reuters', 'PERIODIC', 'PENDING', '2024-07-17', '2024-07-15');

-- =============================================================================
-- WORKFLOW MANAGEMENT SAMPLE DATA
-- =============================================================================

-- Workflow Definition Sample Data
INSERT INTO WorkflowDefinition (workflow_definition_id, workflow_name, workflow_type, workflow_version, description, is_active, auto_start, timeout_hours, created_by, created_date) VALUES
('WF-TRADE-BOOKING-001', 'Equity Swap Trade Booking', 'TRADE_BOOKING', '1.0', 'Complete trade booking workflow from capture to confirmation', TRUE, TRUE, 4, 'system', '2024-01-01'),
('WF-SETTLEMENT-001', 'Settlement Processing', 'SETTLEMENT_PROCESS', '1.0', 'End-to-end settlement processing workflow', TRUE, FALSE, 24, 'system', '2024-01-01'),
('WF-VALUATION-001', 'Daily Valuation Process', 'VALUATION_PROCESS', '1.0', 'Daily mark-to-market valuation workflow', TRUE, TRUE, 6, 'system', '2024-01-01'),
('WF-RECON-DAILY-001', 'Daily Trade Reconciliation', 'RECONCILIATION_PROCESS', '1.0', 'Daily trade reconciliation with external systems', TRUE, TRUE, 8, 'system', '2024-01-01');

-- Workflow Step Sample Data
INSERT INTO WorkflowStep (workflow_step_id, workflow_definition_id, step_name, step_order, step_type, is_mandatory, auto_execute, timeout_minutes, retry_count, prerequisite_steps, configuration, created_date) VALUES
('WS-TRADE-001', 'WF-TRADE-BOOKING-001', 'Trade Validation', 1, 'VALIDATION', TRUE, TRUE, 5, 3, '[]', '{"validation_rules": ["mandatory_fields", "business_rules"]}', '2024-01-01'),
('WS-TRADE-002', 'WF-TRADE-BOOKING-001', 'Trade Enrichment', 2, 'ENRICHMENT', TRUE, TRUE, 10, 2, '["WS-TRADE-001"]', '{"data_sources": ["market_data", "reference_data"]}', '2024-01-01'),
('WS-TRADE-003', 'WF-TRADE-BOOKING-001', 'Risk Approval', 3, 'APPROVAL', TRUE, FALSE, 120, 0, '["WS-TRADE-002"]', '{"approval_threshold": 10000000}', '2024-01-01'),
('WS-TRADE-004', 'WF-TRADE-BOOKING-001', 'Trade Confirmation', 4, 'NOTIFICATION', TRUE, TRUE, 15, 1, '["WS-TRADE-003"]', '{"notification_channels": ["email", "system"]}', '2024-01-01');

-- Workflow Instance Sample Data
INSERT INTO WorkflowInstance (workflow_instance_id, workflow_definition_id, entity_type, entity_id, instance_status, priority_level, started_date, completed_date, created_by, created_date) VALUES
('WI-001', 'WF-TRADE-BOOKING-001', 'TRADE', 'EQS-APPL-001', 'COMPLETED', 3, '2024-01-15 09:00:00', '2024-01-15 09:45:00', 'trader1', '2024-01-15 09:00:00'),
('WI-002', 'WF-TRADE-BOOKING-001', 'TRADE', 'EQS-NIKKEI-001', 'IN_PROGRESS', 2, '2024-01-15 10:30:00', NULL, 'trader2', '2024-01-15 10:30:00'),
('WI-003', 'WF-SETTLEMENT-001', 'SETTLEMENT', 'SETTLE-001', 'COMPLETED', 3, '2024-01-17 08:00:00', '2024-01-17 16:30:00', 'system', '2024-01-17 08:00:00');

-- Workflow Task Sample Data
INSERT INTO WorkflowTask (workflow_task_id, workflow_instance_id, workflow_step_id, task_status, assigned_to, started_date, completed_date, retry_attempts, result_data, created_date) VALUES
('WT-001', 'WI-001', 'WS-TRADE-001', 'COMPLETED', 'system', '2024-01-15 09:00:00', '2024-01-15 09:05:00', 0, '{"validation_result": "PASSED"}', '2024-01-15 09:00:00'),
('WT-002', 'WI-001', 'WS-TRADE-002', 'COMPLETED', 'system', '2024-01-15 09:05:00', '2024-01-15 09:15:00', 0, '{"enrichment_status": "COMPLETED"}', '2024-01-15 09:05:00'),
('WT-003', 'WI-001', 'WS-TRADE-003', 'COMPLETED', 'risk_manager1', '2024-01-15 09:15:00', '2024-01-15 09:30:00', 0, '{"approval_status": "APPROVED"}', '2024-01-15 09:15:00'),
('WT-004', 'WI-002', 'WS-TRADE-001', 'IN_PROGRESS', 'system', '2024-01-15 10:30:00', NULL, 1, NULL, '2024-01-15 10:30:00');

-- =============================================================================
-- EXCEPTION HANDLING SAMPLE DATA
-- =============================================================================

-- Exception Rule Sample Data
INSERT INTO ExceptionRule (exception_rule_id, rule_name, exception_type, entity_type, severity_level, rule_condition, action_type, action_configuration, retry_delay_minutes, escalation_delay_hours, notification_recipients, is_active, created_date) VALUES
('ER-001', 'Auto Retry Validation Errors', 'VALIDATION_ERROR', 'TRADE', 'LOW', '{"max_amount": 1000000}', 'AUTO_RETRY', '{"max_retries": 3}', 5, 2, '["support@example.com"]', TRUE, '2024-01-01'),
('ER-002', 'Escalate Settlement Failures', 'SETTLEMENT_FAIL', 'SETTLEMENT', 'HIGH', '{}', 'ESCALATE', '{"escalation_level": "MANAGER"}', 0, 1, '["settlement.team@example.com", "manager@example.com"]', TRUE, '2024-01-01'),
('ER-003', 'Critical System Errors', 'SYSTEM_ERROR', 'ANY', 'CRITICAL', '{}', 'NOTIFY', '{"immediate_notification": true}', 0, 0, '["support@example.com", "ops.manager@example.com"]', TRUE, '2024-01-01');

-- Exception Sample Data
INSERT INTO Exception (exception_id, exception_type, severity_level, entity_type, entity_id, exception_status, exception_message, exception_details, workflow_instance_id, assigned_to, auto_retry, retry_count, max_retries, next_retry_date, created_by, created_date) VALUES
('EX-001', 'VALIDATION_ERROR', 'LOW', 'TRADE', 'EQS-APPL-002', 'RESOLVED', 'Missing counterparty information', '{"field": "counterparty_id", "validation_rule": "mandatory_field"}', 'WI-004', 'trader1', TRUE, 2, 3, NULL, 'system', '2024-01-15 11:00:00'),
('EX-002', 'SETTLEMENT_FAIL', 'HIGH', 'SETTLEMENT', 'SETTLE-002', 'IN_PROGRESS', 'Insufficient cash balance', '{"required_amount": 1000000, "available_amount": 750000}', NULL, 'settlement_team', FALSE, 0, 0, NULL, 'system', '2024-01-17 09:30:00'),
('EX-003', 'RECON_BREAK', 'MEDIUM', 'VALUATION', 'VAL001', 'NEW', 'Valuation amount mismatch', '{"internal_value": 5000000, "external_value": 4995000, "difference": 5000}', NULL, NULL, FALSE, 0, 0, NULL, 'system', '2024-01-16 18:00:00');

-- =============================================================================
-- STP (STRAIGHT-THROUGH PROCESSING) SAMPLE DATA
-- =============================================================================

-- STP Rule Sample Data
INSERT INTO STPRule (stp_rule_id, rule_name, entity_type, rule_category, rule_condition, auto_process, bypass_manual_check, processing_priority, tolerance_thresholds, business_hours_only, is_active, created_date) VALUES
('STP-001', 'Small Trade Auto-Processing', 'TRADE', 'VALIDATION', '{"trade_amount": {"max": 1000000}, "counterparty_rating": {"min": "A"}}', TRUE, FALSE, 1, '{"amount_tolerance": 1000}', TRUE, TRUE, '2024-01-01'),
('STP-002', 'Standard Settlement STP', 'SETTLEMENT', 'SETTLEMENT', '{"settlement_amount": {"max": 5000000}, "currency": ["USD", "EUR"]}', TRUE, TRUE, 2, '{"amount_tolerance": 100}', FALSE, TRUE, '2024-01-01'),
('STP-003', 'Daily Valuation STP', 'VALUATION', 'APPROVAL', '{"valuation_source": ["BLOOMBERG", "REUTERS"]}', TRUE, FALSE, 3, '{"price_tolerance": 0.01}', TRUE, TRUE, '2024-01-01');

-- STP Status Sample Data
INSERT INTO STPStatus (stp_status_id, entity_type, entity_id, stp_eligible, eligibility_reason, processing_status, stp_percentage, manual_steps_required, processing_started_date, processing_completed_date, workflow_instance_id, created_date) VALUES
('STP-STATUS-001', 'TRADE', 'EQS-APPL-001', TRUE, 'Meets all STP criteria', 'COMPLETED', 100.00, '[]', '2024-01-15 09:00:00', '2024-01-15 09:45:00', 'WI-001', '2024-01-15 09:00:00'),
('STP-STATUS-002', 'TRADE', 'EQS-NIKKEI-001', FALSE, 'High amount requires manual approval', 'MANUAL_REVIEW', 60.00, '["risk_approval", "compliance_check"]', '2024-01-15 10:30:00', NULL, 'WI-002', '2024-01-15 10:30:00'),
('STP-STATUS-003', 'SETTLEMENT', 'SETTLE-001', TRUE, 'Standard settlement criteria met', 'COMPLETED', 95.00, '["final_confirmation"]', '2024-01-17 08:00:00', '2024-01-17 16:30:00', 'WI-003', '2024-01-17 08:00:00');

-- Processing Rule Sample Data
INSERT INTO ProcessingRule (processing_rule_id, rule_name, rule_type, entity_type, rule_expression, action_configuration, execution_order, is_blocking, error_handling, is_active, created_by, created_date) VALUES
('PR-001', 'Trade Amount Validation', 'VALIDATION', 'TRADE', 'trade_amount > 0 AND trade_amount < 100000000', '{"error_message": "Trade amount must be positive and less than 100M"}', 1, TRUE, 'EXCEPTION', TRUE, 'system', '2024-01-01'),
('PR-002', 'Counterparty Enrichment', 'ENRICHMENT', 'TRADE', 'counterparty_id IS NOT NULL', '{"data_source": "COUNTERPARTY_MASTER", "fields": ["credit_rating", "jurisdiction"]}', 2, FALSE, 'WARNING', TRUE, 'system', '2024-01-01'),
('PR-003', 'Settlement Date Validation', 'VALIDATION', 'SETTLEMENT', 'settlement_date >= trade_date + 2', '{"business_rule": "T+2_SETTLEMENT"}', 1, TRUE, 'EXCEPTION', TRUE, 'system', '2024-01-01');

-- =============================================================================
-- RECONCILIATION SAMPLE DATA
-- =============================================================================

-- Reconciliation Rule Sample Data
INSERT INTO ReconciliationRule (recon_rule_id, rule_name, recon_type, matching_criteria, tolerance_rules, break_classification, auto_resolution_rules, priority_order, is_active, effective_date, created_by, created_date) VALUES
('RR-001', 'Trade Matching Rule', 'TRADE_RECON', '{"match_fields": ["trade_id", "trade_date", "counterparty_id"]}', '{"amount_tolerance": 100, "date_tolerance_days": 0}', '{"amount_diff": "AMOUNT_DIFFERENCE", "missing": "MISSING_TRADE"}', '{"auto_resolve_threshold": 50}', 1, TRUE, '2024-01-01', 'system', '2024-01-01'),
('RR-002', 'Position Matching Rule', 'POSITION_RECON', '{"match_fields": ["underlier_id", "position_date", "party_id"]}', '{"quantity_tolerance": 10, "amount_tolerance": 1000}', '{"quantity_diff": "QUANTITY_DIFFERENCE", "amount_diff": "AMOUNT_DIFFERENCE"}', '{"auto_resolve_threshold": 100}', 1, TRUE, '2024-01-01', 'system', '2024-01-01');

-- Reconciliation Run Sample Data
INSERT INTO ReconciliationRun (recon_run_id, recon_type, recon_frequency, business_date, run_status, source_system, target_system, total_records_processed, matched_records, unmatched_records, breaks_identified, tolerance_amount, started_date, completed_date, run_duration_seconds, configuration, created_by, created_date) VALUES
('RR-RUN-001', 'TRADE_RECON', 'DAILY', '2024-01-15', 'COMPLETED', 'INTERNAL_SYSTEM', 'COUNTERPARTY_SYSTEM', 150, 148, 2, 2, 100.00, '2024-01-16 06:00:00', '2024-01-16 06:45:00', 2700, '{"tolerance_override": false}', 'recon_service', '2024-01-16 06:00:00'),
('RR-RUN-002', 'POSITION_RECON', 'DAILY', '2024-01-15', 'COMPLETED', 'INTERNAL_SYSTEM', 'PRIME_BROKER', 75, 73, 2, 3, 1000.00, '2024-01-16 07:00:00', '2024-01-16 07:30:00', 1800, '{"tolerance_override": false}', 'recon_service', '2024-01-16 07:00:00'),
('RR-RUN-003', 'CASH_RECON', 'DAILY', '2024-01-16', 'RUNNING', 'INTERNAL_SYSTEM', 'SETTLEMENT_BANK', 0, 0, 0, 0, 10.00, '2024-01-17 06:00:00', NULL, NULL, '{"tolerance_override": false}', 'recon_service', '2024-01-17 06:00:00');

-- Reconciliation Break Sample Data
INSERT INTO ReconciliationBreak (recon_break_id, recon_run_id, break_type, entity_type, entity_id, break_status, break_amount, break_currency, source_value, target_value, break_description, investigation_notes, assigned_to, exception_id, created_date) VALUES
('RB-001', 'RR-RUN-001', 'AMOUNT_DIFFERENCE', 'TRADE', 'EQS-APPL-001', 'INVESTIGATING', 5000.00, 'USD', '5000000.00', '4995000.00', 'Trade amount difference between internal and counterparty systems', 'Checking trade amendments and settlement instructions', 'recon_analyst1', 'EX-003', '2024-01-16 06:30:00'),
('RB-002', 'RR-RUN-001', 'MISSING_TRADE', 'TRADE', 'EQS-MISSING-001', 'OPEN', NULL, NULL, 'EXISTS', 'NOT_FOUND', 'Trade found in internal system but missing from counterparty system', NULL, 'recon_analyst1', NULL, '2024-01-16 06:35:00'),
('RB-003', 'RR-RUN-002', 'QUANTITY_DIFFERENCE', 'POSITION', 'POS-AAPL-001', 'EXPLAINED', NULL, NULL, '1000', '1010', 'Position quantity difference due to corporate action', 'Corporate action (stock dividend) processed correctly, break resolved', 'recon_analyst2', NULL, '2024-01-16 07:15:00');

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
