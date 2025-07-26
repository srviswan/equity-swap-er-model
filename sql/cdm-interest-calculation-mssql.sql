-- =============================================================================
-- CDM-COMPLIANT INTEREST CALCULATION SYSTEM
-- =============================================================================
-- This system implements CDM-compliant interest calculations using running notional
-- amounts between two dates, supporting various day count conventions and rate types
-- Microsoft SQL Server Version
-- =============================================================================

-- =============================================================================
-- CDM INTEREST CALCULATION PARAMETERS
-- =============================================================================

-- Add CDM-specific calculation parameters to InterestRatePayout
IF NOT EXISTS (SELECT 1 FROM sys.columns 
               WHERE object_id = OBJECT_ID('InterestRatePayout') AND name = 'day_count_convention')
BEGIN
    ALTER TABLE InterestRatePayout 
    ADD day_count_convention VARCHAR(20) NOT NULL DEFAULT 'ACT/360' 
        CHECK (day_count_convention IN ('ACT/360', 'ACT/365', '30/360', '30E/360', 'ACT/ACT')),
        compounding_frequency VARCHAR(20) DEFAULT 'QUARTERLY' 
        CHECK (compounding_frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL')),
        payment_frequency VARCHAR(20) DEFAULT 'QUARTERLY' 
        CHECK (payment_frequency IN ('MONTHLY', 'QUARTERLY', 'SEMI_ANNUAL', 'ANNUAL'));
END
GO

-- =============================================================================
-- CDM INTEREST CALCULATION FUNCTIONS
-- =============================================================================

-- Function to calculate day count fraction based on CDM conventions
IF OBJECT_ID('udf_calculate_day_count_fraction', 'FN') IS NOT NULL
    DROP FUNCTION udf_calculate_day_count_fraction;
GO

CREATE FUNCTION udf_calculate_day_count_fraction
(
    @start_date DATE,
    @end_date DATE,
    @day_count_convention VARCHAR(20)
)
RETURNS DECIMAL(18,10)
AS
BEGIN
    DECLARE @days INT;
    DECLARE @year_days INT;
    DECLARE @fraction DECIMAL(18,10);
    
    SET @days = DATEDIFF(DAY, @start_date, @end_date);
    
    IF @day_count_convention = 'ACT/360'
        SET @fraction = CAST(@days AS DECIMAL(18,10)) / 360.0;
    ELSE IF @day_count_convention = 'ACT/365'
        SET @fraction = CAST(@days AS DECIMAL(18,10)) / 365.0;
    ELSE IF @day_count_convention = '30/360'
    BEGIN
        -- 30/360 day count convention
        DECLARE @d1 INT = DAY(@start_date);
        DECLARE @d2 INT = DAY(@end_date);
        DECLARE @m1 INT = MONTH(@start_date);
        DECLARE @m2 INT = MONTH(@end_date);
        DECLARE @y1 INT = YEAR(@start_date);
        DECLARE @y2 INT = YEAR(@end_date);
        
        IF @d1 = 31 SET @d1 = 30;
        IF @d2 = 31 SET @d2 = 30;
        
        SET @fraction = CAST((@y2 - @y1) * 360 + (@m2 - @m1) * 30 + (@d2 - @d1) AS DECIMAL(18,10)) / 360.0;
    END
    ELSE IF @day_count_convention = 'ACT/ACT'
    BEGIN
        -- ACT/ACT day count convention
        DECLARE @total_days INT = DATEDIFF(DAY, @start_date, @end_date);
        DECLARE @start_year INT = YEAR(@start_date);
        DECLARE @end_year INT = YEAR(@end_date);
        
        IF @start_year = @end_year
            SET @fraction = CAST(@total_days AS DECIMAL(18,10)) / 
                           (CASE WHEN (@start_year % 4 = 0 AND @start_year % 100 != 0) OR (@start_year % 400 = 0) THEN 366 ELSE 365 END);
        ELSE
            SET @fraction = CAST(@total_days AS DECIMAL(18,10)) / 365.0; -- Simplified for SQL Server
    END
    ELSE
        SET @fraction = CAST(@days AS DECIMAL(18,10)) / 360.0; -- Default to ACT/360
    
    RETURN @fraction;
END
GO

-- =============================================================================
-- RUNNING NOTIONAL PERIOD EXTRACTION
-- =============================================================================

-- Revised view for trade inclusion based on settlement date and reset date handling
IF OBJECT_ID('v_trade_interest_periods', 'V') IS NOT NULL
    DROP VIEW v_trade_interest_periods;
GO

CREATE VIEW v_trade_interest_periods AS
WITH 
-- Get trade settlement information
trade_settlement_info AS (
    SELECT 
        t.trade_id,
        t.trade_date,
        s.settlement_date,
        s.settlement_status,
        irp.notional_amount as original_notional,
        irp.fixed_rate,
        irp.day_count_convention
    FROM Trade t
    LEFT JOIN Settlement s ON t.trade_id = s.trade_id
    LEFT JOIN Payout p ON t.product_id = p.product_id
    LEFT JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
    WHERE p.payout_type = 'INTEREST_RATE'
),

-- Get reset events for each trade
reset_events AS (
    SELECT 
        trade_id,
        event_date as reset_date,
        running_settled_notional as post_reset_notional,
        reset_price as post_reset_price,
        ROW_NUMBER() OVER (PARTITION BY trade_id ORDER BY event_date) as reset_sequence
    FROM equity_swap_time_series
    WHERE event_type = 'RESET'
),

-- Get spread override events
spread_override_events AS (
    SELECT 
        trade_id,
        effective_date,
        long_spread,
        short_spread,
        override_type,
        ROW_NUMBER() OVER (PARTITION BY trade_id ORDER BY effective_date) as spread_sequence
    FROM equity_swap_time_series
    WHERE event_type = 'SPREAD_OVERRIDE'
),

-- Get settlement events for each trade
settlement_events AS (
    SELECT 
        trade_id,
        event_date as settlement_event_date,
        running_settled_notional as settled_notional,
        ROW_NUMBER() OVER (PARTITION BY trade_id ORDER BY event_date) as settlement_sequence
    FROM equity_swap_time_series
    WHERE event_type = 'SETTLEMENT'
),

-- Determine the effective notional for each trade based on reset dates
trade_effective_notionals AS (
    SELECT 
        tsi.trade_id,
        tsi.trade_date,
        tsi.settlement_date,
        tsi.settlement_status,
        tsi.original_notional,
        tsi.fixed_rate,
        tsi.day_count_convention,
        
        -- Get the most recent reset before any given date
        COALESCE(
            (
                SELECT TOP 1 re.post_reset_notional
                FROM reset_events re
                WHERE re.trade_id = tsi.trade_id
                ORDER BY re.reset_date DESC
            ),
            tsi.original_notional
        ) as current_post_reset_notional,
        
        -- Latest reset date
        (
            SELECT MAX(re.reset_date)
            FROM reset_events re
            WHERE re.trade_id = tsi.trade_id
        ) as latest_reset_date,
        
        -- Latest spread override
        (
            SELECT TOP 1 soe.long_spread
            FROM spread_override_events soe
            WHERE soe.trade_id = tsi.trade_id
            ORDER BY soe.effective_date DESC
        ) as current_long_spread,
        
        (
            SELECT TOP 1 soe.short_spread
            FROM spread_override_events soe
            WHERE soe.trade_id = tsi.trade_id
            ORDER BY soe.effective_date DESC
        ) as current_short_spread
        
    FROM trade_settlement_info tsi
)

SELECT 
    trade_id,
    trade_date,
    settlement_date,
    settlement_status,
    original_notional,
    current_post_reset_notional,
    fixed_rate,
    day_count_convention,
    latest_reset_date,
    current_long_spread,
    current_short_spread,
    
    -- Determine if trade should be included based on settlement date
    CASE 
        WHEN settlement_date IS NULL THEN 0  -- Exclude if no settlement
        WHEN settlement_status = 'SETTLED' THEN 1  -- Include if settled
        WHEN settlement_status = 'PENDING' AND settlement_date <= GETDATE() THEN 1  -- Include if pending but past settlement
        ELSE 0
    END as include_in_calculation,
    
    -- Effective notional for different scenarios
    CASE 
        WHEN latest_reset_date IS NULL THEN original_notional  -- No reset, use original
        ELSE current_post_reset_notional  -- Use post-reset notional
    END as effective_notional,
    
    -- Metadata for debugging
    JSON_QUERY((
        SELECT 
            trade_id, trade_date, settlement_date, settlement_status,
            original_notional, current_post_reset_notional, latest_reset_date,
            current_long_spread, current_short_spread
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
    )) as trade_details
    
FROM trade_effective_notionals;
GO

-- =============================================================================
-- CDM INTEREST CALCULATION ENGINE
-- =============================================================================

-- Stored procedure to calculate interest for a specific trade and date range
IF OBJECT_ID('sp_calculate_cdm_interest', 'P') IS NOT NULL
    DROP PROCEDURE sp_calculate_cdm_interest;
GO

CREATE PROCEDURE sp_calculate_cdm_interest
    @trade_id VARCHAR(50),
    @start_date DATE,
    @end_date DATE,
    @debug_mode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Temporary table for interest calculations
    CREATE TABLE #cdm_interest_calculations (
        calculation_id INT IDENTITY(1,1) PRIMARY KEY,
        trade_id VARCHAR(50),
        payout_id VARCHAR(50),
        period_start_date DATE,
        period_end_date DATE,
        days_in_period INT,
        day_count_fraction DECIMAL(18,10),
        notional_amount DECIMAL(18,2),
        fixed_rate DECIMAL(8,4),
        interest_amount DECIMAL(18,2),
        calculation_formula VARCHAR(1000),
        calculation_context VARCHAR(500),
        debug_info VARCHAR(MAX)
    );

    -- Get trade and payout information with settlement validation
    DECLARE @payout_id VARCHAR(50);
    DECLARE @fixed_rate DECIMAL(8,4);
    DECLARE @day_count_convention VARCHAR(20);
    DECLARE @settlement_date DATE;
    DECLARE @settlement_status VARCHAR(20);
    DECLARE @trade_date DATE;
    
            rp.settlement_cycle_id,
            
            -- Enhanced calculation formula with context
            CONCAT(
                'Interest = ', 
                CASE 
                    WHEN rp.period_type = 'POST_RESET' THEN FORMAT(rp.end_notional, 'N2')
                    WHEN rp.settlement_cycle_id IS NOT NULL THEN FORMAT(rp.interest_calculation_notional, 'N2')
                    ELSE FORMAT(rp.interest_calculation_notional, 'N2')
                END, 
                ' × ', FORMAT(ip.effective_rate, 'N4'), '% × ', 
                FORMAT(dbo.udf_calculate_day_count_fraction(rp.calc_start_date, rp.calc_end_date, ip.day_count_convention), 'N8'),
                ' [', rp.period_type, ']'
            ) as calculation_formula,
            
            -- Additional context for debugging
            rp.calculation_details
            
        FROM interest_payouts ip
        CROSS JOIN relevant_periods rp
        WHERE rp.calc_start_date < rp.calc_end_date
    -- Insert calculated periods with dynamic spreads
    INSERT INTO #cdm_interest_calculations (
        trade_id,
        payout_id,
        period_start_date,
        period_end_date,
        days_in_period,
        day_count_fraction,
        notional_amount,
        fixed_rate,
        interest_amount,
        calculation_formula,
        calculation_context,
        debug_info
    )
    SELECT 
        trade_id,
        payout_id,
        period_start_date,
        period_end_date,
        DATEDIFF(DAY, period_start_date, period_end_date) as days_in_period,
        dbo.udf_calculate_day_count_fraction(period_start_date, period_end_date, day_count_convention) as day_count_fraction,
        period_notional,
        fixed_rate,
        ROUND(
            period_notional * (fixed_rate + period_spread) * dbo.udf_calculate_day_count_fraction(period_start_date, period_end_date, day_count_convention),
            2
        ) as interest_amount,
        CONCAT(
            'Interest = ', 
            FORMAT(period_notional, 'N2'), 
            ' * (', 
            FORMAT(fixed_rate, 'N4'), 
            ' + ', 
            FORMAT(period_spread, 'N6'), 
            ') * ', 
            FORMAT(dbo.udf_calculate_day_count_fraction(period_start_date, period_end_date, day_count_convention), 'N8')
        ) as calculation_formula,
        CONCAT('Period: [', period_start_date, ' to ', period_end_date, '] Type: ', period_type, ' Spread: ', FORMAT(period_spread, 'N6')) as calculation_context,
        CONCAT('Trade: ', trade_id, ' Settlement: ', @settlement_date, ' Status: ', @settlement_status, ' Context: ', period_context) as debug_info
    FROM (
        SELECT 
            trade_id,
            payout_id,
            period_start_date,
            period_end_date,
            period_notional,
            fixed_rate,
            day_count_convention,
            period_context,
            period_type,
            
            -- Determine the effective spread for this period
            COALESCE(
                -- Use spread override if available
                (
                    SELECT TOP 1 soe.long_spread 
                    FROM spread_override_events soe 
                    WHERE soe.trade_id = cp.trade_id 
                      AND soe.effective_date <= cp.period_start_date
                    ORDER BY soe.effective_date DESC
                ),
                -- Otherwise use default spread
                default_spread
            ) as period_spread
            
        FROM calculation_periods cp
    ) final_periods
    WHERE period_start_date < period_end_date;
    
    -- Return results
    SELECT 
        trade_id,
        payout_id,
        period_start_date,
        period_end_date,
        notional_amount,
        interest_rate,
        day_count_fraction,
        interest_amount,
        day_count_convention,
        calculation_formula,
        CASE 
            WHEN @debug_mode = 1 THEN calculation_details
            ELSE NULL
        END as debug_details
    FROM #cdm_interest_calculations
    ORDER BY period_start_date, period_end_date;
    
    -- Summary results
    SELECT 
        trade_id,
        COUNT(*) as total_periods,
        SUM(interest_amount) as total_interest,
        MIN(period_start_date) as earliest_period,
        MAX(period_end_date) as latest_period,
        AVG(notional_amount) as avg_notional,
        SUM(day_count_fraction) as total_day_count_fraction
    FROM #cdm_interest_calculations
    GROUP BY trade_id;
    
    -- Clean up
    DROP TABLE #cdm_interest_calculations;
END
GO

-- =============================================================================
-- AGGREGATE INTEREST CALCULATION FOR MULTIPLE TRADES
-- =============================================================================

-- Function to calculate aggregate interest across multiple trades
IF OBJECT_ID('udf_calculate_aggregate_interest', 'FN') IS NOT NULL
    DROP FUNCTION udf_calculate_aggregate_interest;
GO

CREATE FUNCTION udf_calculate_aggregate_interest
(
    @start_date DATE,
    @end_date DATE,
    @currency_filter CHAR(3) = NULL
)
RETURNS TABLE
AS
RETURN (
    WITH all_interest AS (
        SELECT 
            t.trade_id,
            t.trade_description,
            p.payout_id,
            irp.notional_currency,
            irp.rate_type,
            irp.fixed_rate,
            irp.floating_rate_index,
            irp.spread,
            irp.day_count_convention,
            c.period_start_date,
            c.period_end_date,
            c.notional_amount,
            c.interest_rate,
            c.day_count_fraction,
            c.interest_amount
        FROM Trade t
        CROSS APPLY (
            EXEC sp_calculate_cdm_interest t.trade_id, @start_date, @end_date, 0
        ) c
        JOIN Payout p ON c.payout_id = p.payout_id
        JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
        WHERE (@currency_filter IS NULL OR irp.notional_currency = @currency_filter)
    )
    SELECT 
        trade_id,
        trade_description,
        payout_id,
        notional_currency,
        rate_type,
        period_start_date,
        period_end_date,
        notional_amount,
        interest_rate,
        day_count_fraction,
        interest_amount,
        SUM(interest_amount) OVER (PARTITION BY trade_id) as total_trade_interest,
        SUM(interest_amount) OVER (PARTITION BY notional_currency) as total_currency_interest
    FROM all_interest
);
GO

-- =============================================================================
-- INTEREST ACCRUAL SCHEDULE GENERATION
-- =============================================================================

-- Stored procedure to generate interest accrual schedule
IF OBJECT_ID('sp_generate_interest_accrual_schedule', 'P') IS NOT NULL
    DROP PROCEDURE sp_generate_interest_accrual_schedule;
GO

CREATE PROCEDURE sp_generate_interest_accrual_schedule
    @trade_id VARCHAR(50),
    @accrual_start_date DATE,
    @accrual_end_date DATE,
    @payment_frequency VARCHAR(20) = 'QUARTERLY'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Determine payment dates based on frequency
    DECLARE @payment_dates TABLE (
        payment_date DATE,
        period_start DATE,
        period_end DATE
    );
    
    WITH payment_periods AS (
        SELECT 
            @accrual_start_date as period_start,
            CASE 
                WHEN @payment_frequency = 'MONTHLY' THEN DATEADD(MONTH, 1, @accrual_start_date)
                WHEN @payment_frequency = 'QUARTERLY' THEN DATEADD(QUARTER, 1, @accrual_start_date)
                WHEN @payment_frequency = 'SEMI_ANNUAL' THEN DATEADD(MONTH, 6, @accrual_start_date)
                WHEN @payment_frequency = 'ANNUAL' THEN DATEADD(YEAR, 1, @accrual_start_date)
                ELSE DATEADD(QUARTER, 1, @accrual_start_date)
            END as period_end
        
        UNION ALL
        
        SELECT 
            period_end,
            CASE 
                WHEN @payment_frequency = 'MONTHLY' THEN DATEADD(MONTH, 1, period_end)
                WHEN @payment_frequency = 'QUARTERLY' THEN DATEADD(QUARTER, 1, period_end)
                WHEN @payment_frequency = 'SEMI_ANNUAL' THEN DATEADD(MONTH, 6, period_end)
                WHEN @payment_frequency = 'ANNUAL' THEN DATEADD(YEAR, 1, period_end)
                ELSE DATEADD(QUARTER, 1, period_end)
            END
        FROM payment_periods
        WHERE period_end < @accrual_end_date
    )
    INSERT INTO @payment_dates
    SELECT 
        CASE WHEN period_end > @accrual_end_date THEN @accrual_end_date ELSE period_end END,
        period_start,
        CASE WHEN period_end > @accrual_end_date THEN @accrual_end_date ELSE period_end END
    FROM payment_periods;
    
    -- Calculate interest for each period
    SELECT 
        pd.payment_date,
        pd.period_start,
        pd.period_end,
        irp.notional_amount,
        irp.fixed_rate,
        irp.spread,
        dbo.udf_calculate_day_count_fraction(pd.period_start, pd.period_end, irp.day_count_convention) as day_count_fraction,
        ROUND(
            irp.notional_amount * 
            (COALESCE(irp.fixed_rate, 0) + COALESCE(irp.spread, 0)) / 100.0 * 
            dbo.udf_calculate_day_count_fraction(pd.period_start, pd.period_end, irp.day_count_convention),
            2
        ) as scheduled_interest,
        irp.day_count_convention,
        irp.rate_type
    FROM @payment_dates pd
    CROSS JOIN (
        SELECT 
            irp.notional_amount,
            irp.fixed_rate,
            irp.spread,
            irp.day_count_convention,
            irp.rate_type
        FROM Trade t
        JOIN Payout p ON t.product_id = p.product_id
        JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
        WHERE t.trade_id = @trade_id
          AND p.payout_type = 'INTEREST_RATE'
    ) irp
    ORDER BY pd.payment_date;
END
GO

-- =============================================================================
-- VALIDATION AND TESTING QUERIES
-- =============================================================================

-- View to validate interest calculations
IF OBJECT_ID('v_interest_calculation_validation', 'V') IS NOT NULL
    DROP VIEW v_interest_calculation_validation;
GO

CREATE VIEW v_interest_calculation_validation AS
WITH validation_data AS (
    SELECT 
        t.trade_id,
        t.trade_description,
        p.payout_id,
        irp.notional_amount as original_notional,
        irp.fixed_rate,
        irp.spread,
        irp.day_count_convention,
        
        -- Get actual cash flows
        cf.cash_flow_id,
        cf.scheduled_date,
        cf.scheduled_amount,
        cf.accrual_start_date,
        cf.accrual_end_date,
        
        -- Calculate expected amount
        ROUND(
            irp.notional_amount * 
            (COALESCE(irp.fixed_rate, 0) + COALESCE(irp.spread, 0)) / 100.0 * 
            dbo.udf_calculate_day_count_fraction(cf.accrual_start_date, cf.accrual_end_date, irp.day_count_convention),
            2
        ) as expected_amount,
        
        -- Validation
        CASE 
            WHEN ABS(cf.scheduled_amount - 
                     ROUND(
                         irp.notional_amount * 
                         (COALESCE(irp.fixed_rate, 0) + COALESCE(irp.spread, 0)) / 100.0 * 
                         dbo.udf_calculate_day_count_fraction(cf.accrual_start_date, cf.accrual_end_date, irp.day_count_convention),
                         2
                     )
                 ) < 0.01 
            THEN 'VALID'
            ELSE 'INVALID'
        END as validation_status
        
    FROM Trade t
    JOIN Payout p ON t.product_id = p.product_id
    JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
    JOIN CashFlow cf ON p.payout_id = cf.payout_id
    WHERE cf.flow_type = 'INTEREST_PAYMENT'
      AND cf.payment_status IN ('SCHEDULED', 'PAID')
)
SELECT 
    trade_id,
    trade_description,
    payout_id,
    original_notional,
    fixed_rate,
    spread,
    day_count_convention,
    COUNT(*) as total_flows,
    SUM(CASE WHEN validation_status = 'VALID' THEN 1 ELSE 0 END) as valid_flows,
    SUM(CASE WHEN validation_status = 'INVALID' THEN 1 ELSE 0 END) as invalid_flows,
    SUM(scheduled_amount) as total_scheduled,
    SUM(expected_amount) as total_expected,
    CASE 
        WHEN COUNT(*) = SUM(CASE WHEN validation_status = 'VALID' THEN 1 ELSE 0 END)
        THEN 'ALL_VALID'
        WHEN SUM(CASE WHEN validation_status = 'INVALID' THEN 1 ELSE 0 END) > 0
        THEN 'HAS_INVALID'
        ELSE 'PARTIAL'
    END as overall_validation
FROM validation_data
GROUP BY trade_id, trade_description, payout_id, original_notional, fixed_rate, spread, day_count_convention
ORDER BY trade_id;
GO

-- =============================================================================
-- USAGE EXAMPLES AND TESTING
-- =============================================================================

-- Example 1: Calculate interest for a specific trade and date range
PRINT '=== CDM Interest Calculation Examples ===';
PRINT '';
PRINT 'Example 1: Calculate interest for trade TRD001 from 2024-01-01 to 2024-12-31';
PRINT '';

-- EXEC sp_calculate_cdm_interest 'TRD001', '2024-01-01', '2024-12-31', 1;

-- Example 2: Generate accrual schedule for quarterly payments
PRINT 'Example 2: Generate quarterly accrual schedule';
PRINT '';

-- EXEC sp_generate_interest_accrual_schedule 'TRD001', '2024-01-01', '2024-12-31', 'QUARTERLY';

-- Example 3: Validate all interest calculations
PRINT 'Example 3: Validation of all interest calculations';
PRINT '';

-- SELECT * FROM v_interest_calculation_validation;

SELECT 'CDM Interest Calculation System Created Successfully' AS status;
GO
