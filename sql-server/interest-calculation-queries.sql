-- Interest Calculation Queries
-- Demonstrates proper linkage between CashFlow and InterestRatePayout notional amounts
-- Microsoft SQL Server implementation

-- Query 1: Current Interest Calculations with Notional Linkage
-- Shows how interest cash flows reference InterestRatePayout.notional_amount
SELECT 
    cf.cash_flow_id,
    cf.trade_id,
    t.trade_description,
    cf.flow_type,
    cf.scheduled_date,
    cf.actual_payment_date,
    cf.currency,
    cf.scheduled_amount as calculated_interest,
    cf.reference_rate,
    cf.accrual_start_date,
    cf.accrual_end_date,
    DATEDIFF(day, cf.accrual_start_date, cf.accrual_end_date) as accrual_days,
    
    -- Link to InterestRatePayout for notional source
    irp.notional_amount as payout_notional,
    irp.rate_type,
    irp.fixed_rate,
    irp.floating_rate_index,
    irp.spread,
    irp.day_count_fraction,
    irp.notional_currency,
    
    -- Parse JSON calculation details
    JSON_VALUE(cf.calculation_details, '$.source_payout') as source_payout_id,
    JSON_VALUE(cf.calculation_details, '$.notional_source') as notional_source,
    CAST(JSON_VALUE(cf.calculation_details, '$.original_notional') AS DECIMAL(18,2)) as original_notional,
    CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2)) as effective_notional,
    CAST(JSON_VALUE(cf.calculation_details, '$.avg_rate') AS DECIMAL(8,4)) as effective_rate,
    JSON_VALUE(cf.calculation_details, '$.calculation') as calculation_formula,
    
    -- Validation: Check if calculated amount matches expected
    CASE 
        WHEN cf.flow_type = 'INTEREST_PAYMENT' THEN
            ROUND(
                CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2)) * 
                (CAST(JSON_VALUE(cf.calculation_details, '$.avg_rate') AS DECIMAL(8,4)) / 100.0) *
                DATEDIFF(day, cf.accrual_start_date, cf.accrual_end_date) / 360.0,
                2
            )
        ELSE NULL
    END as validation_amount,
    
    -- Validation result
    CASE 
        WHEN cf.flow_type = 'INTEREST_PAYMENT' AND 
             ABS(cf.scheduled_amount - 
                 ROUND(
                     CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2)) * 
                     (CAST(JSON_VALUE(cf.calculation_details, '$.avg_rate') AS DECIMAL(8,4)) / 100.0) *
                     DATEDIFF(day, cf.accrual_start_date, cf.accrual_end_date) / 360.0,
                     2
                 )
             ) < 0.01 
        THEN 'VALID'
        WHEN cf.flow_type = 'INTEREST_PAYMENT' THEN 'INVALID'
        ELSE 'N/A'
    END as calculation_validation

FROM CashFlow cf
JOIN Trade t ON cf.trade_id = t.trade_id
JOIN Payout p ON cf.payout_id = p.payout_id
LEFT JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
WHERE cf.flow_type = 'INTEREST_PAYMENT'
ORDER BY cf.trade_id, cf.scheduled_date;

-- Query 2: Interest Notional Adjustments Over Trade Lifecycle
-- Shows how notional amounts change through partial terminations
WITH InterestLifecycle AS (
    SELECT 
        cf.trade_id,
        cf.cash_flow_id,
        cf.scheduled_date,
        cf.flow_type,
        cf.scheduled_amount,
        
        -- Extract notional information from JSON
        CAST(JSON_VALUE(cf.calculation_details, '$.original_notional') AS DECIMAL(18,2)) as original_notional,
        CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2)) as effective_notional,
        CAST(JSON_VALUE(cf.calculation_details, '$.current_notional') AS DECIMAL(18,2)) as current_notional,
        CAST(JSON_VALUE(cf.calculation_details, '$.terminated_notional') AS DECIMAL(18,2)) as terminated_notional,
        CAST(JSON_VALUE(cf.calculation_details, '$.remaining_notional') AS DECIMAL(18,2)) as remaining_notional,
        
        JSON_VALUE(cf.calculation_details, '$.termination_type') as termination_type,
        JSON_VALUE(cf.calculation_details, '$.post_termination') as post_termination,
        JSON_VALUE(cf.calculation_details, '$.notional_adjustment') as notional_adjustment,
        
        -- Calculate running notional balance
        CASE 
            WHEN JSON_VALUE(cf.calculation_details, '$.current_notional') IS NOT NULL 
            THEN CAST(JSON_VALUE(cf.calculation_details, '$.current_notional') AS DECIMAL(18,2))
            WHEN JSON_VALUE(cf.calculation_details, '$.effective_notional') IS NOT NULL 
            THEN CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2))
            ELSE CAST(JSON_VALUE(cf.calculation_details, '$.original_notional') AS DECIMAL(18,2))
        END as running_notional,
        
        ROW_NUMBER() OVER (PARTITION BY cf.trade_id ORDER BY cf.scheduled_date) as payment_sequence
    
    FROM CashFlow cf
    WHERE cf.flow_type = 'INTEREST_PAYMENT'
)
SELECT 
    trade_id,
    payment_sequence,
    cash_flow_id,
    scheduled_date,
    scheduled_amount,
    original_notional,
    running_notional,
    terminated_notional,
    remaining_notional,
    termination_type,
    notional_adjustment,
    
    -- Show notional changes
    LAG(running_notional) OVER (PARTITION BY trade_id ORDER BY scheduled_date) as previous_notional,
    CASE 
        WHEN LAG(running_notional) OVER (PARTITION BY trade_id ORDER BY scheduled_date) IS NOT NULL
        THEN running_notional - LAG(running_notional) OVER (PARTITION BY trade_id ORDER BY scheduled_date)
        ELSE 0
    END as notional_change,
    
    -- Calculate effective interest rate
    CASE 
        WHEN running_notional > 0 AND scheduled_date IS NOT NULL
        THEN ABS(scheduled_amount) / (running_notional * DATEDIFF(day, 
            LAG(scheduled_date, 1, '2024-01-01') OVER (PARTITION BY trade_id ORDER BY scheduled_date), 
            scheduled_date) / 360.0) * 100
        ELSE NULL
    END as implied_annual_rate

FROM InterestLifecycle
ORDER BY trade_id, payment_sequence;

-- Query 3: Validate Interest Calculations Against InterestRatePayout
-- Ensures all interest cash flows properly reference their payout notional amounts
SELECT 
    t.trade_id,
    t.trade_description,
    
    -- Payout Details
    p.payout_id,
    p.payout_type,
    irp.notional_amount as payout_notional,
    irp.notional_currency,
    irp.rate_type,
    irp.fixed_rate,
    irp.floating_rate_index,
    irp.spread,
    
    -- Cash Flow Summary
    COUNT(cf.cash_flow_id) as total_interest_flows,
    SUM(CASE WHEN cf.payment_status = 'PAID' THEN 1 ELSE 0 END) as paid_flows,
    SUM(CASE WHEN cf.payment_status = 'SCHEDULED' THEN 1 ELSE 0 END) as scheduled_flows,
    SUM(cf.scheduled_amount) as total_scheduled_interest,
    SUM(CASE WHEN cf.payment_status = 'PAID' THEN cf.actual_amount ELSE 0 END) as total_paid_interest,
    
    -- Notional Validation
    COUNT(DISTINCT CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2))) as unique_notionals_used,
    MIN(CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2))) as min_notional_used,
    MAX(CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2))) as max_notional_used,
    
    -- Validation Flags
    CASE 
        WHEN COUNT(CASE WHEN JSON_VALUE(cf.calculation_details, '$.source_payout') = p.payout_id THEN 1 END) = COUNT(cf.cash_flow_id)
        THEN 'ALL_FLOWS_REFERENCE_PAYOUT'
        ELSE 'MISSING_PAYOUT_REFERENCES'
    END as payout_reference_validation,
    
    CASE 
        WHEN COUNT(CASE WHEN JSON_VALUE(cf.calculation_details, '$.notional_source') = 'InterestRatePayout.notional_amount' THEN 1 END) = COUNT(cf.cash_flow_id)
        THEN 'ALL_FLOWS_REFERENCE_NOTIONAL_SOURCE'
        ELSE 'MISSING_NOTIONAL_SOURCE_REFERENCES'
    END as notional_source_validation

FROM Trade t
JOIN Payout p ON t.trade_id IN (
    SELECT DISTINCT cf_inner.trade_id 
    FROM CashFlow cf_inner 
    WHERE cf_inner.payout_id = p.payout_id
)
JOIN InterestRatePayout irp ON p.payout_id = irp.payout_id
LEFT JOIN CashFlow cf ON p.payout_id = cf.payout_id AND cf.flow_type = 'INTEREST_PAYMENT'
WHERE p.payout_type = 'INTEREST_RATE'
GROUP BY t.trade_id, t.trade_description, p.payout_id, p.payout_type, 
         irp.notional_amount, irp.notional_currency, irp.rate_type, 
         irp.fixed_rate, irp.floating_rate_index, irp.spread
ORDER BY t.trade_id;

-- Query 4: Interest Settlement Cycle Analysis
-- Shows how interest calculations handle settlement cycle quantities
SELECT 
    cf.trade_id,
    cf.cash_flow_id,
    cf.scheduled_date,
    cf.scheduled_amount,
    
    -- Extract settlement cycle information
    JSON_VALUE(cf.calculation_details, '$.source_payout') as source_payout,
    JSON_VALUE(cf.calculation_details, '$.notional_source') as notional_source,
    
    -- Notional tracking through lifecycle
    CAST(JSON_VALUE(cf.calculation_details, '$.original_notional') AS DECIMAL(18,2)) as original_notional,
    CAST(JSON_VALUE(cf.calculation_details, '$.effective_notional') AS DECIMAL(18,2)) as effective_notional,
    CAST(JSON_VALUE(cf.calculation_details, '$.current_notional') AS DECIMAL(18,2)) as current_notional,
    
    -- Termination adjustments
    JSON_VALUE(cf.calculation_details, '$.termination_type') as termination_type,
    CAST(JSON_VALUE(cf.calculation_details, '$.termination_percentage') AS DECIMAL(5,2)) as termination_percentage,
    CAST(JSON_VALUE(cf.calculation_details, '$.terminated_notional') AS DECIMAL(18,2)) as terminated_notional,
    CAST(JSON_VALUE(cf.calculation_details, '$.remaining_notional') AS DECIMAL(18,2)) as remaining_notional,
    JSON_VALUE(cf.calculation_details, '$.notional_adjustment') as notional_adjustment,
    
    -- Rate components
    CAST(JSON_VALUE(cf.calculation_details, '$.avg_rate') AS DECIMAL(8,4)) as effective_rate,
    CAST(JSON_VALUE(cf.calculation_details, '$.sofr_rate') AS DECIMAL(8,4)) as base_rate,
    CAST(JSON_VALUE(cf.calculation_details, '$.spread') AS DECIMAL(8,4)) as spread,
    
    -- Calculation details
    CAST(JSON_VALUE(cf.calculation_details, '$.accrual_days') AS INT) as accrual_days,
    JSON_VALUE(cf.calculation_details, '$.day_count') as day_count_convention,
    JSON_VALUE(cf.calculation_details, '$.calculation') as formula,
    
    -- Lifecycle notes
    JSON_VALUE(cf.calculation_details, '$.note') as lifecycle_note,
    JSON_VALUE(cf.calculation_details, '$.lifecycle_note') as additional_notes

FROM CashFlow cf
WHERE cf.flow_type = 'INTEREST_PAYMENT'
  AND JSON_VALUE(cf.calculation_details, '$.notional_source') = 'InterestRatePayout.notional_amount'
ORDER BY cf.trade_id, cf.scheduled_date;
