-- =============================================================================
-- EQUITY SWAP RUNNING NOTIONAL AND QUANTITY CALCULATION SYSTEM
-- =============================================================================
-- This system implements efficient running notional and quantity calculations
-- for equity swap lifecycle management with reset price adjustments
-- =============================================================================

-- =============================================================================
-- ENHANCED TRADE TABLE - Add activity tracking fields
-- =============================================================================

-- Add activity tracking columns to Trade table if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'trade' AND column_name = 'activity_quantity'
    ) THEN
        ALTER TABLE Trade 
        ADD COLUMN activity_quantity DECIMAL(18,6) NOT NULL DEFAULT 0,
        ADD COLUMN activity_notional DECIMAL(18,2) NOT NULL DEFAULT 0,
        ADD COLUMN settlement_date DATE,
        ADD COLUMN settlement_amount DECIMAL(18,2) DEFAULT 0,
        ADD COLUMN direction VARCHAR(10) CHECK (direction IN ('BUY', 'SELL', 'LONG', 'SHORT'));
    END IF;
END $$;

-- =============================================================================
-- RESET EVENT TRACKING - Enhanced observation events for resets
-- =============================================================================

-- Create ResetEvent table specifically for tracking reset prices
CREATE TABLE IF NOT EXISTS ResetEvent (
    reset_id VARCHAR(50) PRIMARY KEY,
    trade_id VARCHAR(50) NOT NULL,
    reset_date DATE NOT NULL,
    reset_price DECIMAL(18,6) NOT NULL CHECK (reset_price > 0),
    reset_type VARCHAR(20) NOT NULL CHECK (reset_type IN ('SCHEDULED', 'AD_HOC', 'CORPORATE_ACTION')),
    previous_reset_price DECIMAL(18,6),
    reset_reason TEXT,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reset_trade 
        FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) ON DELETE CASCADE
);

-- Create indexes for reset events
CREATE INDEX IF NOT EXISTS idx_reset_trade_date ON ResetEvent(trade_id, reset_date);
CREATE INDEX IF NOT EXISTS idx_reset_date ON ResetEvent(reset_date);

-- =============================================================================
-- EVENT-BASED TIME SERIES VIEW
-- =============================================================================

-- Create a comprehensive event view combining trades, settlements, and resets
CREATE OR REPLACE VIEW trade_event_timeline AS
WITH 
-- Trade execution events
trade_events AS (
    SELECT 
        t.trade_id,
        t.trade_date AS event_date,
        'TRADE_EXECUTION' AS event_type,
        t.activity_quantity,
        t.activity_notional,
        t.settlement_date,
        t.settlement_amount,
        t.direction,
        1 AS event_priority,
        t.created_timestamp
    FROM Trade t
),

-- Settlement events (when running quantities actually change)
settlement_events AS (
    SELECT 
        s.trade_id,
        s.settlement_date AS event_date,
        'SETTLEMENT' AS event_type,
        t.activity_quantity,
        t.activity_notional,
        s.settlement_date,
        s.settlement_amount,
        t.direction,
        2 AS event_priority,
        s.created_timestamp
    FROM Settlement s
    JOIN Trade t ON s.trade_id = t.trade_id
    WHERE s.settlement_status = 'SETTLED'
),

-- Reset events
reset_events AS (
    SELECT 
        r.trade_id,
        r.reset_date AS event_date,
        'RESET' AS event_type,
        0 AS activity_quantity,  -- Resets don't change quantity
        0 AS activity_notional,  -- Resets don't change notional directly
        NULL AS settlement_date,
        0 AS settlement_amount,
        NULL AS direction,
        0 AS event_priority,  -- Resets have highest priority
        r.created_timestamp
    FROM ResetEvent r
),

-- Combine all events
all_events AS (
    SELECT * FROM trade_events
    UNION ALL
    SELECT * FROM settlement_events
    UNION ALL
    SELECT * FROM reset_events
)

SELECT 
    ROW_NUMBER() OVER (ORDER BY event_date, event_priority, created_timestamp) AS sequence_id,
    trade_id,
    event_date,
    event_type,
    activity_quantity,
    activity_notional,
    settlement_date,
    settlement_amount,
    direction,
    event_priority,
    created_timestamp
FROM all_events;

-- =============================================================================
-- AGGREGATED TRADE VIEW - Handle multiple trades on same dates
-- =============================================================================

CREATE OR REPLACE VIEW aggregated_trade_events AS
WITH aggregated_events AS (
    SELECT 
        trade_id,
        event_date,
        event_type,
        SUM(activity_quantity) AS total_quantity,
        SUM(activity_notional) AS total_notional,
        MIN(settlement_date) AS settlement_date,
        SUM(settlement_amount) AS total_settlement_amount,
        CASE 
            WHEN SUM(CASE WHEN direction = 'BUY' THEN 1 ELSE -1 END * activity_quantity) > 0 
            THEN 'LONG' 
            ELSE 'SHORT' 
        END AS net_direction,
        MIN(event_priority) AS event_priority,
        MIN(created_timestamp) AS first_created
    FROM trade_event_timeline
    WHERE event_type IN ('TRADE_EXECUTION', 'SETTLEMENT')
    GROUP BY trade_id, event_date, event_type
),

reset_events_aggregated AS (
    SELECT 
        trade_id,
        event_date,
        event_type,
        0 AS total_quantity,
        0 AS total_notional,
        NULL AS settlement_date,
        0 AS total_settlement_amount,
        NULL AS net_direction,
        0 AS event_priority,
        MIN(created_timestamp) AS first_created
    FROM trade_event_timeline
    WHERE event_type = 'RESET'
    GROUP BY trade_id, event_date, event_type
)

SELECT * FROM aggregated_events
UNION ALL
SELECT * FROM reset_events_aggregated
ORDER BY event_date, event_priority, first_created;

-- =============================================================================
-- RUNNING NOTIONAL CALCULATION WITH RESET PRICE ADJUSTMENTS
-- =============================================================================

CREATE OR REPLACE VIEW running_notional_calculation AS
WITH 
-- Get the latest reset price as of each event date
latest_reset_prices AS (
    SELECT 
        a.trade_id,
        a.event_date,
        COALESCE(
            LAST_VALUE(r.reset_price) IGNORE NULLS OVER (
                PARTITION BY a.trade_id 
                ORDER BY a.event_date, a.event_priority, a.first_created
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            -- Default to initial price from first trade if no reset
            (SELECT t.activity_notional / NULLIF(t.activity_quantity, 0) 
             FROM Trade t WHERE t.trade_id = a.trade_id LIMIT 1)
        ) AS current_reset_price
    FROM aggregated_trade_events a
    LEFT JOIN ResetEvent r ON a.trade_id = r.trade_id AND r.reset_date <= a.event_date
),

-- Calculate running totals
running_totals AS (
    SELECT 
        a.sequence_id,
        a.trade_id,
        a.event_date,
        a.event_type,
        a.total_quantity,
        a.total_notional,
        a.total_settlement_amount,
        a.net_direction,
        l.current_reset_price,
        -- Running settled quantity (only changes on settlement)
        SUM(CASE 
            WHEN a.event_type = 'SETTLEMENT' THEN a.total_quantity 
            ELSE 0 
        END) OVER (
            PARTITION BY a.trade_id 
            ORDER BY a.event_date, a.event_priority, a.first_created
        ) AS running_settled_quantity,
        
        -- Running settled notional (adjusted by latest reset price)
        SUM(CASE 
            WHEN a.event_type = 'SETTLEMENT' THEN a.total_quantity * l.current_reset_price
            ELSE 0 
        END) OVER (
            PARTITION BY a.trade_id 
            ORDER BY a.event_date, a.event_priority, a.first_created
        ) AS running_settled_notional,
        
        -- Running total quantity (including unsettled trades)
        SUM(a.total_quantity) OVER (
            PARTITION BY a.trade_id 
            ORDER BY a.event_date, a.event_priority, a.first_created
        ) AS running_total_quantity,
        
        -- Running total notional (including unsettled trades)
        SUM(a.total_notional) OVER (
            PARTITION BY a.trade_id 
            ORDER BY a.event_date, a.event_priority, a.first_created
        ) AS running_total_notional,
        
        a.first_created
    FROM aggregated_trade_events a
    JOIN latest_reset_prices l ON a.trade_id = l.trade_id AND a.event_date = l.event_date
)

SELECT 
    sequence_id,
    trade_id,
    event_date,
    event_type,
    total_quantity AS event_quantity,
    total_notional AS event_notional,
    total_settlement_amount AS event_settlement,
    net_direction,
    current_reset_price,
    running_settled_quantity,
    running_settled_notional,
    running_total_quantity,
    running_total_notional,
    -- Calculate unsettled amounts
    running_total_quantity - running_settled_quantity AS unsettled_quantity,
    running_total_notional - running_settled_notional AS unsettled_notional,
    first_created
FROM running_totals
ORDER BY trade_id, event_date, sequence_id;

-- =============================================================================
-- TIME SERIES OUTPUT VIEW - Optimized for sparse events
-- =============================================================================

CREATE OR REPLACE VIEW equity_swap_time_series AS
SELECT 
    trade_id,
    event_date,
    event_type,
    event_quantity,
    event_notional,
    event_settlement,
    net_direction,
    ROUND(current_reset_price, 6) AS reset_price,
    ROUND(running_settled_quantity, 6) AS settled_quantity,
    ROUND(running_settled_notional, 2) AS settled_notional,
    ROUND(running_total_quantity, 6) AS total_quantity,
    ROUND(running_total_notional, 2) AS total_notional,
    ROUND(unsettled_quantity, 6) AS unsettled_quantity,
    ROUND(unsettled_notional, 2) AS unsettled_notional,
    -- Calculate mark-to-market value
    ROUND(running_settled_quantity * current_reset_price, 2) AS mark_to_market_value,
    -- Days since last event
    event_date - LAG(event_date) OVER (PARTITION BY trade_id ORDER BY event_date) AS days_since_last_event,
    first_created
FROM running_notional_calculation;

-- =============================================================================
-- SUMMARY VIEW - Latest position per trade
-- =============================================================================

CREATE OR REPLACE VIEW latest_trade_positions AS
WITH latest_events AS (
    SELECT 
        trade_id,
        MAX(sequence_id) AS max_sequence_id
    FROM running_notional_calculation
    GROUP BY trade_id
)
SELECT 
    t.trade_id,
    tr.trade_date,
    p.product_name,
    u.asset_name AS underlying_asset,
    pos.event_date AS last_event_date,
    pos.settled_quantity,
    pos.settled_notional,
    pos.total_quantity,
    pos.total_notional,
    pos.reset_price AS latest_reset_price,
    pos.mark_to_market_value,
    pos.net_direction,
    tr.status
FROM latest_events le
JOIN running_notional_calculation pos ON le.max_sequence_id = pos.sequence_id
JOIN Trade tr ON pos.trade_id = tr.trade_id
JOIN TradableProduct p ON tr.product_id = p.product_id
LEFT JOIN PerformancePayout pp ON p.product_id = pp.payout_id
LEFT JOIN PerformancePayoutUnderlier ppu ON pp.performance_payout_id = ppu.performance_payout_id
LEFT JOIN Underlier u ON ppu.underlier_id = u.underlier_id;

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Function to get running position for a specific trade on a specific date
CREATE OR REPLACE FUNCTION get_trade_position(
    p_trade_id VARCHAR(50),
    p_as_of_date DATE
) RETURNS TABLE (
    trade_id VARCHAR(50),
    as_of_date DATE,
    settled_quantity DECIMAL(18,6),
    settled_notional DECIMAL(18,2),
    total_quantity DECIMAL(18,6),
    total_notional DECIMAL(18,2),
    reset_price DECIMAL(18,6),
    mark_to_market_value DECIMAL(18,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        trade_id,
        event_date AS as_of_date,
        settled_quantity,
        settled_notional,
        total_quantity,
        total_notional,
        reset_price,
        mark_to_market_value
    FROM equity_swap_time_series
    WHERE trade_id = p_trade_id
      AND event_date <= p_as_of_date
    ORDER BY event_date DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get time series for a date range
CREATE OR REPLACE FUNCTION get_trade_time_series(
    p_trade_id VARCHAR(50),
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
) RETURNS TABLE (
    sequence_num BIGINT,
    event_date DATE,
    event_type VARCHAR(20),
    event_quantity DECIMAL(18,6),
    event_notional DECIMAL(18,2),
    settled_quantity DECIMAL(18,6),
    settled_notional DECIMAL(18,2),
    reset_price DECIMAL(18,6),
    mark_to_market_value DECIMAL(18,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY event_date)::BIGINT,
        event_date,
        event_type,
        event_quantity,
        event_notional,
        settled_quantity,
        settled_notional,
        reset_price,
        mark_to_market_value
    FROM equity_swap_time_series
    WHERE trade_id = p_trade_id
      AND (p_start_date IS NULL OR event_date >= p_start_date)
      AND (p_end_date IS NULL OR event_date <= p_end_date)
    ORDER BY event_date;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_trade_activity ON Trade(activity_quantity, activity_notional, settlement_date);
CREATE INDEX IF NOT EXISTS idx_reset_event_lookup ON ResetEvent(trade_id, reset_date);
CREATE INDEX IF NOT EXISTS idx_settlement_status_date ON Settlement(settlement_status, settlement_date);

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Query to validate running calculations
CREATE OR REPLACE VIEW calculation_validation AS
SELECT 
    trade_id,
    COUNT(*) AS event_count,
    MIN(event_date) AS first_event,
    MAX(event_date) AS last_event,
    SUM(CASE WHEN event_type = 'TRADE_EXECUTION' THEN event_quantity ELSE 0 END) AS total_traded_quantity,
    SUM(CASE WHEN event_type = 'SETTLEMENT' THEN event_quantity ELSE 0 END) AS total_settled_quantity,
    MAX(settled_quantity) AS final_settled_quantity,
    MAX(settled_notional) AS final_settled_notional,
    MAX(reset_price) AS latest_reset_price
FROM equity_swap_time_series
GROUP BY trade_id
ORDER BY trade_id;

SELECT 'Equity Swap Running Notional Calculation System Created Successfully' AS status;
