-- =============================================================================
-- TEST DATA FOR RUNNING NOTIONAL CALCULATION SYSTEM
-- =============================================================================
-- This script provides comprehensive test data covering:
-- 1. Multiple trades on same dates (aggregation)
-- 2. Multiple reset events with price adjustments
-- 3. Various settlement dates
-- 4. Sparse trading patterns
-- =============================================================================

-- =============================================================================
-- ENHANCE EXISTING TRADES WITH ACTIVITY TRACKING
-- =============================================================================

-- Update existing trades with activity tracking fields
UPDATE Trade SET 
    activity_quantity = 1000,
    activity_notional = 150000.00,
    settlement_date = trade_date + INTERVAL '2 business days',
    settlement_amount = 150000.00,
    direction = 'LONG'
WHERE trade_id IN ('TRADE001', 'TRADE002', 'TRADE003');

-- =============================================================================
-- SAMPLE TRADES FOR TESTING
-- =============================================================================

-- Insert additional test trades with various scenarios
INSERT INTO Trade (trade_id, product_id, trade_date, trade_time, activity_quantity, activity_notional, settlement_date, settlement_amount, direction, status, created_timestamp) VALUES
-- Scenario 1: Basic single trade
('TEST001', 'PROD001', '2024-01-15', '09:30:00', 1000, 150000.00, '2024-01-17', 150000.00, 'LONG', 'ACTIVE', '2024-01-15 09:30:00'),

-- Scenario 2: Multiple trades on same date (should aggregate)
('TEST002', 'PROD001', '2024-01-16', '10:15:00', 500, 75000.00, '2024-01-18', 75000.00, 'LONG', 'ACTIVE', '2024-01-16 10:15:00'),
('TEST003', 'PROD001', '2024-01-16', '14:30:00', 300, 45000.00, '2024-01-18', 45000.00, 'LONG', 'ACTIVE', '2024-01-16 14:30:00'),

-- Scenario 3: Short position trade
('TEST004', 'PROD001', '2024-01-17', '11:00:00', -800, -120000.00, '2024-01-19', -120000.00, 'SHORT', 'ACTIVE', '2024-01-17 11:00:00'),

-- Scenario 4: Trade with later settlement
('TEST005', 'PROD001', '2024-01-18', '09:45:00', 1200, 180000.00, '2024-01-22', 180000.00, 'LONG', 'ACTIVE', '2024-01-18 09:45:00'),

-- Scenario 5: Sparse trading - large gap
('TEST006', 'PROD001', '2024-02-01', '10:00:00', 2000, 320000.00, '2024-02-05', 320000.00, 'LONG', 'ACTIVE', '2024-02-01 10:00:00'),

-- Scenario 6: Partial closeout
('TEST007', 'PROD001', '2024-02-05', '15:30:00', -1500, -240000.00, '2024-02-07', -240000.00, 'SHORT', 'ACTIVE', '2024-02-05 15:30:00'),

-- Scenario 7: Another sparse trade
('TEST008', 'PROD001', '2024-03-01', '09:15:00', 2500, 400000.00, '2024-03-05', 400000.00, 'LONG', 'ACTIVE', '2024-03-01 09:15:00');

-- =============================================================================
-- SETTLEMENT RECORDS
-- =============================================================================

-- Insert settlement records for all test trades
INSERT INTO Settlement (settlement_id, trade_id, settlement_date, settlement_type, settlement_amount, settlement_currency, payer_party_id, receiver_party_id, settlement_status, settled_timestamp) VALUES
('SETL001', 'TEST001', '2024-01-17', 'CASH', 150000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-01-17 16:00:00'),
('SETL002', 'TEST002', '2024-01-18', 'CASH', 75000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-01-18 16:00:00'),
('SETL003', 'TEST003', '2024-01-18', 'CASH', 45000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-01-18 16:00:00'),
('SETL004', 'TEST004', '2024-01-19', 'CASH', -120000.00, 'USD', 'PARTY001', 'PARTY002', 'SETTLED', '2024-01-19 16:00:00'),
('SETL005', 'TEST005', '2024-01-22', 'CASH', 180000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-01-22 16:00:00'),
('SETL006', 'TEST006', '2024-02-05', 'CASH', 320000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-02-05 16:00:00'),
('SETL007', 'TEST007', '2024-02-07', 'CASH', -240000.00, 'USD', 'PARTY001', 'PARTY002', 'SETTLED', '2024-02-07 16:00:00'),
('SETL008', 'TEST008', '2024-03-05', 'CASH', 400000.00, 'USD', 'PARTY002', 'PARTY001', 'SETTLED', '2024-03-05 16:00:00');

-- =============================================================================
-- RESET EVENTS WITH PRICE CHANGES
-- =============================================================================

-- Insert reset events with various price scenarios
INSERT INTO ResetEvent (reset_id, trade_id, reset_date, reset_price, reset_type, reset_reason) VALUES
-- Initial reset for TEST001
('RST001', 'TEST001', '2024-01-15', 150.00, 'SCHEDULED', 'Initial reset price'),

-- Price increase reset
('RST002', 'TEST001', '2024-01-20', 165.00, 'SCHEDULED', 'Weekly reset - price increased'),

-- Price decrease reset
('RST003', 'TEST001', '2024-01-27', 142.50, 'SCHEDULED', 'Weekly reset - price decreased'),

-- Corporate action reset
('RST004', 'TEST001', '2024-02-01', 138.75, 'CORPORATE_ACTION', 'Dividend adjustment'),

-- Multiple resets for TEST002-003 (same underlying)
('RST005', 'TEST002', '2024-01-16', 150.00, 'SCHEDULED', 'Initial reset'),
('RST006', 'TEST002', '2024-01-23', 158.00, 'SCHEDULED', 'Weekly reset'),
('RST007', 'TEST002', '2024-01-30', 145.00, 'SCHEDULED', 'Weekly reset'),

-- Resets for TEST004 (short position)
('RST008', 'TEST004', '2024-01-17', 150.00, 'SCHEDULED', 'Initial reset'),
('RST009', 'TEST004', '2024-01-24', 148.00, 'SCHEDULED', 'Weekly reset'),

-- Sparse resets for later trades
('RST010', 'TEST006', '2024-02-01', 160.00, 'SCHEDULED', 'Initial reset'),
('RST011', 'TEST006', '2024-02-15', 175.00, 'SCHEDULED', 'Bi-weekly reset'),

('RST012', 'TEST008', '2024-03-01', 160.00, 'SCHEDULED', 'Initial reset'),
('RST013', 'TEST008', '2024-03-15', 168.00, 'SCHEDULED', 'Bi-weekly reset');

-- =============================================================================
-- OBSERVATION EVENTS FOR PRICE TRACKING
-- =============================================================================

-- Insert observation events to support reset calculations
INSERT INTO ObservationEvent (observation_id, trade_id, observation_date, underlier_id, observed_price, observation_type) VALUES
('OBS001', 'TEST001', '2024-01-15', 'UND001', 150.00, 'CLOSING_PRICE'),
('OBS002', 'TEST001', '2024-01-20', 'UND001', 165.00, 'CLOSING_PRICE'),
('OBS003', 'TEST001', '2024-01-27', 'UND001', 142.50, 'CLOSING_PRICE'),
('OBS004', 'TEST001', '2024-02-01', 'UND001', 138.75, 'CLOSING_PRICE'),
('OBS005', 'TEST002', '2024-01-16', 'UND001', 150.00, 'CLOSING_PRICE'),
('OBS006', 'TEST002', '2024-01-23', 'UND001', 158.00, 'CLOSING_PRICE'),
('OBS007', 'TEST002', '2024-01-30', 'UND001', 145.00, 'CLOSING_PRICE'),
('OBS008', 'TEST004', '2024-01-17', 'UND001', 150.00, 'CLOSING_PRICE'),
('OBS009', 'TEST004', '2024-01-24', 'UND001', 148.00, 'CLOSING_PRICE'),
('OBS010', 'TEST006', '2024-02-01', 'UND001', 160.00, 'CLOSING_PRICE'),
('OBS011', 'TEST006', '2024-02-15', 'UND001', 175.00, 'CLOSING_PRICE'),
('OBS012', 'TEST008', '2024-03-01', 'UND001', 160.00, 'CLOSING_PRICE'),
('OBS013', 'TEST008', '2024-03-15', 'UND001', 168.00, 'CLOSING_PRICE');

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Test query to verify aggregation of same-date trades
CREATE OR REPLACE VIEW test_aggregation_validation AS
SELECT 
    trade_id,
    trade_date,
    SUM(activity_quantity) AS total_quantity,
    SUM(activity_notional) AS total_notional,
    COUNT(*) AS trade_count
FROM Trade
WHERE trade_date = '2024-01-16'
GROUP BY trade_id, trade_date
ORDER BY trade_date;

-- Test query to verify reset price application
CREATE OR REPLACE VIEW test_reset_price_validation AS
SELECT 
    r.trade_id,
    r.reset_date,
    r.reset_price,
    r.reset_type,
    COUNT(*) OVER (PARTITION BY r.trade_id) AS reset_count
FROM ResetEvent r
ORDER BY r.trade_id, r.reset_date;

-- Test query to verify settlement progression
CREATE OR REPLACE VIEW test_settlement_progression AS
SELECT 
    s.trade_id,
    s.settlement_date,
    s.settlement_amount,
    t.activity_quantity,
    t.direction,
    CASE 
        WHEN t.direction = 'LONG' THEN 'BUY'
        WHEN t.direction = 'SHORT' THEN 'SELL'
    END AS trade_side
FROM Settlement s
JOIN Trade t ON s.trade_id = t.trade_id
ORDER BY s.trade_id, s.settlement_date;

SELECT 'Test Data for Running Notional Calculation Created Successfully' AS status;
