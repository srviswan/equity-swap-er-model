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
-- PAYOUTS - COMPREHENSIVE CASH FLOW MODELING
-- =============================================================================

-- Performance Payouts (Equity Return Leg)
INSERT INTO Payout (payout_id, economic_terms_id, payer_party_id, receiver_party_id, payout_type, payment_frequency, settlement_currency, created_date) VALUES
('PAY001', 'ET001', 'PARTY001', 'PARTY002', 'PERFORMANCE', 'QUARTERLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY002', 'ET002', 'PARTY004', 'PARTY003', 'PERFORMANCE', 'MONTHLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY003', 'ET003', 'PARTY005', 'PARTY002', 'PERFORMANCE', 'QUARTERLY', 'USD', CAST(GETDATE() AS DATE));

-- Interest Rate Payouts (Funding Leg)
INSERT INTO Payout (payout_id, economic_terms_id, payer_party_id, receiver_party_id, payout_type, payment_frequency, settlement_currency, created_date) VALUES
('PAY004', 'ET001', 'PARTY002', 'PARTY001', 'INTEREST_RATE', 'QUARTERLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY005', 'ET002', 'PARTY003', 'PARTY004', 'INTEREST_RATE', 'MONTHLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY006', 'ET004', 'PARTY001', 'PARTY003', 'INTEREST_RATE', 'QUARTERLY', 'EUR', CAST(GETDATE() AS DATE));

-- Dividend Payouts (Dividend Pass-through)
INSERT INTO Payout (payout_id, economic_terms_id, payer_party_id, receiver_party_id, payout_type, payment_frequency, settlement_currency, created_date) VALUES
('PAY007', 'ET001', 'PARTY001', 'PARTY002', 'DIVIDEND', 'QUARTERLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY008', 'ET002', 'PARTY004', 'PARTY003', 'DIVIDEND', 'QUARTERLY', 'USD', CAST(GETDATE() AS DATE)),
('PAY009', 'ET005', 'PARTY002', 'PARTY005', 'DIVIDEND', 'SEMI_ANNUALLY', 'JPY', CAST(GETDATE() AS DATE));

-- =============================================================================
-- PERFORMANCE PAYOUT DETAILS
-- =============================================================================

-- Equity performance payout specifications
INSERT INTO PerformancePayout (performance_payout_id, payout_id, return_type, initial_price, initial_price_date, notional_amount, notional_currency, observation_start_date, observation_end_date, market_disruption_events) VALUES
('PERF001', 'PAY001', 'TOTAL_RETURN', 150.25, '2024-01-02', 10000000.00, 'USD', '2024-01-02', '2024-12-31', N'[{"event_type":"TRADING_DISRUPTION","fallback":"DELAYED_VALUATION"}]'),
('PERF002', 'PAY002', 'PRICE_RETURN', 2825.50, '2024-01-02', 5000000.00, 'USD', '2024-01-02', '2024-12-31', N'[{"event_type":"MARKET_CLOSURE","fallback":"PRECEDING_BUSINESS_DAY"}]'),
('PERF003', 'PAY003', 'VARIANCE_RETURN', 25.80, '2024-01-02', 2000000.00, 'USD', '2024-01-02', '2024-12-31', N'[{"event_type":"DELISTING","fallback":"REPLACEMENT_SECURITY"}]');

-- =============================================================================
-- INTEREST RATE PAYOUT DETAILS
-- =============================================================================

-- Interest rate payout specifications (funding leg)
INSERT INTO InterestRatePayout (interest_payout_id, payout_id, rate_type, fixed_rate, floating_rate_index, spread, day_count_fraction, reset_frequency, compounding_method, notional_amount, notional_currency) VALUES
('INT001', 'PAY004', 'FLOATING', NULL, 'USD-SOFR', 0.0050, 'ACT/360', 'DAILY', 'FLAT', 10000000.00, 'USD'),
('INT002', 'PAY005', 'FIXED', 0.0325, NULL, 0.0000, 'ACT/365', 'MONTHLY', 'NONE', 5000000.00, 'USD'),
('INT003', 'PAY006', 'FLOATING', NULL, 'EUR-ESTR', 0.0025, 'ACT/360', 'DAILY', 'FLAT', 8000000.00, 'EUR');

-- =============================================================================
-- DIVIDEND PAYOUT DETAILS
-- =============================================================================

-- Dividend payout specifications
INSERT INTO DividendPayout (dividend_payout_id, payout_id, dividend_treatment, dividend_percentage, ex_dividend_treatment, withholding_tax_rate, minimum_dividend_amount, dividend_currency, payment_delay_days) VALUES
('DIV001', 'PAY007', 'PASS_THROUGH', 100.00, 'CASH_PAYMENT', 0.15, 0.01, 'USD', 2),
('DIV002', 'PAY008', 'PASS_THROUGH', 85.00, 'CASH_PAYMENT', 0.30, 0.01, 'USD', 3),
('DIV003', 'PAY009', 'REINVESTMENT', 100.00, 'REINVESTMENT', 0.20, 100.00, 'JPY', 0);

-- =============================================================================
-- SAMPLE CASH FLOWS
-- =============================================================================

-- Performance cash flows (quarterly settlements)
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF001', 'PAY001', 'TRD001', 'EQUITY_PERFORMANCE', 'INFLOW', '2024-03-29', '2024-03-29', 'USD', 125000.00, 125000.00, N'{"performance_period":"Q1_2024","initial_value":10000000,"final_value":10125000,"return_pct":1.25}', 'PAID', '2024-01-02', '2024-03-29'),
('CF002', 'PAY001', 'TRD001', 'EQUITY_PERFORMANCE', 'OUTFLOW', '2024-06-28', NULL, 'USD', -87500.00, NULL, N'{"performance_period":"Q2_2024","initial_value":10125000,"final_value":10037500,"return_pct":-0.875}', 'SCHEDULED', '2024-03-29', '2024-06-28');

-- Interest rate cash flows (funding leg)
-- Calculations based on InterestRatePayout.notional_amount from PAY004
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, reference_rate, accrual_start_date, accrual_end_date) VALUES
('CF003', 'PAY004', 'TRD001', 'INTEREST_PAYMENT', 'OUTFLOW', '2024-03-29', '2024-03-29', 'USD', -95000.00, -95000.00, N'{"source_payout":"PAY004","notional_source":"InterestRatePayout.notional_amount","original_notional":10000000,"effective_notional":10000000,"avg_rate":3.75,"spread":0.50,"sofr_rate":3.25,"accrual_days":88,"day_count":"ACT/360","calculation":"10000000 * 3.75% * 88/360"}', 'PAID', 3.7500, '2024-01-02', '2024-03-29'),
('CF004', 'PAY004', 'TRD001', 'INTEREST_PAYMENT', 'OUTFLOW', '2024-06-28', NULL, 'USD', -98250.00, NULL, N'{"source_payout":"PAY004","notional_source":"InterestRatePayout.notional_amount","original_notional":10000000,"effective_notional":10000000,"avg_rate":3.83,"spread":0.50,"sofr_rate":3.33,"accrual_days":91,"day_count":"ACT/360","calculation":"10000000 * 3.83% * 91/360"}', 'SCHEDULED', 3.8300, '2024-03-29', '2024-06-28');

-- Dividend cash flows
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF005', 'PAY007', 'TRD001', 'DIVIDEND_PAYMENT', 'INFLOW', '2024-02-15', '2024-02-17', 'USD', 8750.00, 7437.50, N'{"gross_dividend":8750,"withholding_tax":1312.50,"tax_rate":15.0,"shares_equivalent":1000}', 'PAID', '2024-02-13', '2024-02-15'),
('CF006', 'PAY007', 'TRD001', 'DIVIDEND_PAYMENT', 'INFLOW', '2024-05-15', '2024-05-17', 'USD', 9250.00, 7862.50, N'{"gross_dividend":9250,"withholding_tax":1387.50,"tax_rate":15.0,"shares_equivalent":1000}', 'PAID', '2024-05-13', '2024-05-15');

-- =============================================================================
-- PARTIAL TERMINATION SCENARIO - REALIZED CASH FLOWS
-- =============================================================================

-- Scenario: 40% of TRD001 position terminated on 2024-07-15
-- Original notional: $10M, Terminated portion: $4M (40%)
-- Equity performance from inception to termination date

-- REALIZED PERFORMANCE PAYOUT (Partial Termination)
-- Equity moved from $150.25 to $162.85 (+8.38% total return)
-- Terminated portion: $4M * 8.38% = $335,200 realized gain
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF007', 'PAY001', 'TRD001', 'EQUITY_PERFORMANCE', 'INFLOW', '2024-07-15', '2024-07-17', 'USD', 335200.00, 335200.00, 
N'{"termination_type":"PARTIAL","terminated_notional":4000000,"initial_price":150.25,"final_price":162.85,"total_return_pct":8.38,"inception_date":"2024-01-02","termination_date":"2024-07-15","performance_breakdown":{"price_return":8.38,"dividend_yield":2.15,"total_return":8.38}}', 
'PAID', '2024-01-02', '2024-07-15');

-- REALIZED INTEREST PAYOUT (Partial Termination)
-- Final interest payment on terminated portion - calculated from InterestRatePayout notional
-- Original notional: 10M, Terminated: 40% = 4M, Remaining: 60% = 6M
-- Accrued from 2024-06-28 to 2024-07-15 (17 days)
-- Rate: SOFR 3.85% + 0.50% spread = 4.35%
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, reference_rate, accrual_start_date, accrual_end_date) VALUES
('CF008', 'PAY004', 'TRD001', 'INTEREST_PAYMENT', 'OUTFLOW', '2024-07-15', '2024-07-17', 'USD', -8150.00, -8150.00, 
N'{"termination_type":"PARTIAL","source_payout":"PAY004","notional_source":"InterestRatePayout.notional_amount","original_notional":10000000,"termination_percentage":40.0,"terminated_notional":4000000,"remaining_notional":6000000,"avg_rate":4.35,"spread":0.50,"sofr_rate":3.85,"accrual_days":17,"day_count":"ACT/360","calculation":"(10000000 * 0.40) * 4.35% * 17/360","notional_adjustment":"POST_TERMINATION_REDUCTION"}', 
'PAID', 4.3500, '2024-06-28', '2024-07-15');

-- REALIZED DIVIDEND PAYOUT (Partial Termination)
-- Pro-rata dividend accrual on terminated portion
-- Accrued dividend from 2024-05-15 to 2024-07-15 (61 days)
-- Estimated quarterly dividend: $2.25/share, pro-rated
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF009', 'PAY007', 'TRD001', 'DIVIDEND_PAYMENT', 'INFLOW', '2024-07-15', '2024-07-17', 'USD', 3250.00, 2762.50, 
N'{"termination_type":"PARTIAL","accrual_type":"PRO_RATA","terminated_shares_equivalent":400,"quarterly_dividend_per_share":2.25,"accrual_days":61,"quarter_days":91,"gross_accrued":3250,"withholding_tax":487.50,"tax_rate":15.0,"calculation":"400 shares * $2.25 * 61/91 days"}', 
'PAID', '2024-05-15', '2024-07-15');

-- =============================================================================
-- POST-TERMINATION CASH FLOWS (Remaining 60% Position)
-- =============================================================================

-- Continuing performance cash flows on remaining $6M notional
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF010', 'PAY001', 'TRD001', 'EQUITY_PERFORMANCE', 'OUTFLOW', '2024-09-30', NULL, 'USD', -45000.00, NULL, 
N'{"remaining_notional":6000000,"performance_period":"Q3_2024","post_termination":true,"price_change_pct":-0.75,"calculation":"6000000 * -0.75%"}', 
'SCHEDULED', '2024-06-28', '2024-09-30');

-- Continuing interest payments on remaining notional after partial termination
-- Updated InterestRatePayout.notional_amount should reflect the reduced notional
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, reference_rate, accrual_start_date, accrual_end_date) VALUES
('CF011', 'PAY004', 'TRD001', 'INTEREST_PAYMENT', 'OUTFLOW', '2024-09-30', NULL, 'USD', -67250.00, NULL, 
N'{"source_payout":"PAY004","notional_source":"InterestRatePayout.notional_amount","original_notional":10000000,"current_notional":6000000,"post_termination":true,"termination_adjustment":"NOTIONAL_REDUCED_BY_40_PERCENT","avg_rate":4.25,"spread":0.50,"sofr_rate":3.75,"accrual_days":95,"day_count":"ACT/360","calculation":"6000000 * 4.25% * 95/360","note":"Notional reduced from 10M to 6M after partial termination"}', 
'SCHEDULED', 4.2500, '2024-06-28', '2024-09-30');

-- Continuing dividend payments on remaining position
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF012', 'PAY007', 'TRD001', 'DIVIDEND_PAYMENT', 'INFLOW', '2024-08-15', '2024-08-17', 'USD', 6750.00, 5737.50, 
N'{"remaining_shares_equivalent":600,"quarterly_dividend_per_share":2.25,"gross_dividend":6750,"withholding_tax":1012.50,"tax_rate":15.0,"post_termination":true}', 
'PAID', '2024-08-13', '2024-08-15');

-- =============================================================================
-- FULL TERMINATION SCENARIO - COMPLETE SETTLEMENT
-- =============================================================================

-- Scenario: TRD002 (S&P 500 Index Swap) fully terminated on 2024-08-30
-- Original trade: $5M notional, inception 2024-01-02, early termination
-- Final settlement of all accrued performance, interest, and dividend amounts

-- FINAL PERFORMANCE SETTLEMENT (Full Termination)
-- S&P 500 moved from 4,825.50 to 5,475.25 (+13.47% total return over 8 months)
-- Full notional: $5M * 13.47% = $673,500 realized gain
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF013', 'PAY002', 'TRD002', 'EQUITY_PERFORMANCE', 'INFLOW', '2024-08-30', '2024-09-03', 'USD', 673500.00, 673500.00, 
N'{"termination_type":"FULL","total_notional":5000000,"initial_index_level":4825.50,"final_index_level":5475.25,"total_return_pct":13.47,"inception_date":"2024-01-02","termination_date":"2024-08-30","holding_period_months":8,"performance_breakdown":{"capital_appreciation":11.22,"dividend_yield":2.25,"total_return":13.47},"realized_pnl":673500}', 
'PAID', '2024-01-02', '2024-08-30');

-- FINAL INTEREST SETTLEMENT (Full Termination)
-- Final funding cost payment calculated from InterestRatePayout.notional_amount for PAY005
-- Accrued from last payment 2024-07-31 to termination 2024-08-30 (30 days)
-- Current rate: SOFR 4.15% + 0.50% spread = 4.65%
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, reference_rate, accrual_start_date, accrual_end_date) VALUES
('CF014', 'PAY005', 'TRD002', 'INTEREST_PAYMENT', 'OUTFLOW', '2024-08-30', '2024-09-03', 'USD', -19375.00, -19375.00, 
N'{"termination_type":"FULL","source_payout":"PAY005","notional_source":"InterestRatePayout.notional_amount","total_notional":5000000,"final_payment":true,"final_rate":4.65,"spread":0.50,"sofr_rate":4.15,"accrual_days":30,"day_count":"ACT/360","calculation":"5000000 * 4.65% * 30/360","ytd_interest_paid":145250.00,"total_funding_cost":164625.00,"lifecycle_note":"Final settlement uses full original notional as no partial termination occurred"}', 
'PAID', 4.6500, '2024-07-31', '2024-08-30');

-- FINAL DIVIDEND SETTLEMENT (Full Termination)
-- Settlement of all accrued dividends to termination date
-- Includes: Q2 ex-dividend accrual + Q3 partial accrual
-- Total accrued: $18,750 gross dividends
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF015', 'PAY008', 'TRD002', 'DIVIDEND_PAYMENT', 'INFLOW', '2024-08-30', '2024-09-03', 'USD', 18750.00, 13125.00, 
N'{"termination_type":"FULL","final_dividend_settlement":true,"total_shares_equivalent":500,"accrued_periods":[{"period":"Q2_2024","dividend_per_share":2.85,"amount":1425},{"period":"Q3_2024_PARTIAL","dividend_per_share":3.10,"accrual_days":61,"quarter_days":92,"amount":17325}],"gross_total":18750,"withholding_tax":5625,"tax_rate":30.0,"net_settlement":13125}', 
'PAID', '2024-06-15', '2024-08-30');

-- TERMINATION FEE (if applicable)
-- Early termination fee as per ISDA agreement
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF016', 'PAY005', 'TRD002', 'FEE_PAYMENT', 'OUTFLOW', '2024-08-30', '2024-09-03', 'USD', -12500.00, -12500.00, 
N'{"termination_type":"FULL","fee_type":"EARLY_TERMINATION","fee_basis":"NOTIONAL_PERCENTAGE","fee_rate":0.25,"calculation":"5000000 * 0.25%","contractual_basis":"ISDA_MASTER_AGREEMENT"}', 
'PAID', '2024-08-30', '2024-08-30');

-- NET SETTLEMENT SUMMARY
-- Final net settlement amount across all cash flows
INSERT INTO CashFlow (cash_flow_id, payout_id, trade_id, flow_type, flow_direction, scheduled_date, actual_payment_date, currency, scheduled_amount, actual_amount, calculation_details, payment_status, accrual_start_date, accrual_end_date) VALUES
('CF017', 'PAY002', 'TRD002', 'PRINCIPAL_PAYMENT', 'INFLOW', '2024-08-30', '2024-09-03', 'USD', 654750.00, 654750.00, 
N'{"termination_type":"FULL","settlement_type":"NET_CASH_SETTLEMENT","component_breakdown":{"performance_gain":673500,"interest_cost":-19375,"dividend_income":13125,"termination_fee":-12500,"net_settlement":654750},"trade_pnl_summary":{"total_performance":673500,"total_funding_cost":-164625,"total_dividends":48750,"total_fees":-12500,"net_pnl":545125}}', 
'PAID', '2024-01-02', '2024-08-30');

-- =============================================================================
-- TRADE STATUS UPDATES
-- =============================================================================

-- Update trade status to reflect terminations
-- TRD001: Partially terminated (reduced notional)
-- TRD002: Fully terminated

-- Note: Trade status updates would typically be handled via UPDATE statements
-- Sample UPDATE statements for demonstration:
-- UPDATE Trade SET status = 'PARTIALLY_TERMINATED', updated_timestamp = GETDATE() WHERE trade_id = 'TRD001';
-- UPDATE Trade SET status = 'TERMINATED', updated_timestamp = GETDATE() WHERE trade_id = 'TRD002';

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
