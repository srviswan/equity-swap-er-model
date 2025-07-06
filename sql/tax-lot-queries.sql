-- Tax Lot Methodology Query Examples
-- Demonstrates various tax lot efficiency methods for equity swap unwinds

-- 1. LIFO (Last In, First Out) Unwind Selection
-- Select lots for unwinding using LIFO methodology
WITH lifo_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.lot_number,
        tl.current_notional,
        tl.current_shares,
        tl.cost_basis,
        tl.total_cost_basis,
        tl.acquisition_date,
        tl.acquisition_time,
        
        -- Calculate running total for partial unwinds
        SUM(tl.current_notional) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.acquisition_date DESC, tl.acquisition_time DESC
            ROWS UNBOUNDED PRECEDING
        ) as running_total,
        
        -- Rank by LIFO criteria
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.acquisition_date DESC, tl.acquisition_time DESC
        ) as lifo_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001' -- Example trade
)
SELECT 
    tax_lot_id,
    lot_number,
    current_notional,
    cost_basis,
    acquisition_date,
    lifo_rank,
    running_total,
    CASE 
        WHEN running_total <= 3000000 THEN current_notional  -- Full lot if under target
        WHEN running_total - current_notional < 3000000 THEN 3000000 - (running_total - current_notional) -- Partial lot
        ELSE 0 -- Skip lot
    END as unwind_amount
FROM lifo_lot_selection
WHERE running_total - current_notional < 3000000 -- Only lots needed for $3M unwind
ORDER BY lifo_rank;

-- 2. FIFO (First In, First Out) Unwind Selection
-- Select lots for unwinding using FIFO methodology
WITH fifo_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.lot_number,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        tl.acquisition_time,
        
        -- Calculate holding period for tax classification
        CURRENT_DATE - tl.acquisition_date as holding_period_days,
        CASE 
            WHEN CURRENT_DATE - tl.acquisition_date > 365 THEN 'LONG_TERM'
            ELSE 'SHORT_TERM'
        END as tax_treatment,
        
        SUM(tl.current_notional) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.acquisition_date ASC, tl.acquisition_time ASC
            ROWS UNBOUNDED PRECEDING
        ) as running_total,
        
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.acquisition_date ASC, tl.acquisition_time ASC
        ) as fifo_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001'
)
SELECT 
    tax_lot_id,
    lot_number,
    current_notional,
    cost_basis,
    acquisition_date,
    holding_period_days,
    tax_treatment,
    fifo_rank,
    CASE 
        WHEN running_total <= 3000000 THEN current_notional
        WHEN running_total - current_notional < 3000000 THEN 3000000 - (running_total - current_notional)
        ELSE 0
    END as unwind_amount
FROM fifo_lot_selection
WHERE running_total - current_notional < 3000000
ORDER BY fifo_rank;

-- 3. HICO (Highest Cost First) for Gain Minimization
-- Select highest cost basis lots first to minimize realized gains
WITH hico_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.current_notional,
        tl.cost_basis,
        tl.total_cost_basis,
        tl.acquisition_date,
        
        -- Calculate potential gain/loss at current market price
        (190.00 - tl.cost_basis) * tl.current_shares as potential_gain_loss,
        (190.00 - tl.cost_basis) as gain_loss_per_share,
        
        SUM(tl.current_notional) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis DESC, tl.acquisition_date ASC
            ROWS UNBOUNDED PRECEDING
        ) as running_total,
        
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis DESC, tl.acquisition_date ASC
        ) as hico_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001'
)
SELECT 
    tax_lot_id,
    current_notional,
    cost_basis,
    gain_loss_per_share,
    potential_gain_loss,
    hico_rank,
    CASE 
        WHEN running_total <= 3000000 THEN current_notional
        WHEN running_total - current_notional < 3000000 THEN 3000000 - (running_total - current_notional)
        ELSE 0
    END as unwind_amount,
    CASE 
        WHEN running_total <= 3000000 THEN potential_gain_loss
        WHEN running_total - current_notional < 3000000 THEN 
            potential_gain_loss * ((3000000 - (running_total - current_notional)) / current_notional)
        ELSE 0
    END as realized_gain_loss
FROM hico_lot_selection
WHERE running_total - current_notional < 3000000
ORDER BY hico_rank;

-- 4. LOCO (Lowest Cost First) for Loss Realization
-- Select lowest cost basis lots first to maximize realized losses
WITH loco_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        
        -- Calculate potential gain/loss
        (185.00 - tl.cost_basis) * tl.current_shares as potential_gain_loss,
        
        SUM(tl.current_notional) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis ASC, tl.acquisition_date ASC
            ROWS UNBOUNDED PRECEDING
        ) as running_total,
        
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis ASC, tl.acquisition_date ASC
        ) as loco_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001'
)
SELECT 
    tax_lot_id,
    current_notional,
    cost_basis,
    potential_gain_loss,
    loco_rank,
    CASE 
        WHEN running_total <= 3000000 THEN current_notional
        WHEN running_total - current_notional < 3000000 THEN 3000000 - (running_total - current_notional)
        ELSE 0
    END as unwind_amount
FROM loco_lot_selection
WHERE running_total - current_notional < 3000000
ORDER BY loco_rank;

-- 5. Tax-Optimized Selection (Mixed Strategy)
-- Prioritize long-term losses, then short-term losses, then long-term gains, finally short-term gains
WITH tax_optimized_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        
        -- Tax classification
        CASE 
            WHEN CURRENT_DATE - tl.acquisition_date > 365 THEN 'LONG_TERM'
            ELSE 'SHORT_TERM'
        END as tax_treatment,
        
        -- Gain/Loss classification at $188 market price
        CASE 
            WHEN 188.00 > tl.cost_basis THEN 'GAIN'
            ELSE 'LOSS'
        END as gain_loss_type,
        
        (188.00 - tl.cost_basis) * tl.current_shares as potential_gain_loss,
        
        -- Tax optimization priority (1 = best, 4 = worst)
        CASE 
            WHEN CURRENT_DATE - tl.acquisition_date > 365 AND 188.00 < tl.cost_basis THEN 1 -- Long-term loss
            WHEN CURRENT_DATE - tl.acquisition_date <= 365 AND 188.00 < tl.cost_basis THEN 2 -- Short-term loss  
            WHEN CURRENT_DATE - tl.acquisition_date > 365 AND 188.00 >= tl.cost_basis THEN 3 -- Long-term gain
            ELSE 4 -- Short-term gain
        END as tax_priority,
        
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id,
            CASE 
                WHEN CURRENT_DATE - tl.acquisition_date > 365 AND 188.00 < tl.cost_basis THEN 1
                WHEN CURRENT_DATE - tl.acquisition_date <= 365 AND 188.00 < tl.cost_basis THEN 2
                WHEN CURRENT_DATE - tl.acquisition_date > 365 AND 188.00 >= tl.cost_basis THEN 3
                ELSE 4
            END
            ORDER BY ABS(188.00 - tl.cost_basis) DESC, tl.acquisition_date ASC
        ) as priority_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001'
),
tax_optimized_with_running_total AS (
    SELECT *,
        SUM(current_notional) OVER (
            ORDER BY tax_priority, priority_rank
            ROWS UNBOUNDED PRECEDING
        ) as running_total
    FROM tax_optimized_selection
)
SELECT 
    tax_lot_id,
    current_notional,
    cost_basis,
    tax_treatment,
    gain_loss_type,
    potential_gain_loss,
    tax_priority,
    priority_rank,
    CASE 
        WHEN running_total <= 3000000 THEN current_notional
        WHEN running_total - current_notional < 3000000 THEN 3000000 - (running_total - current_notional)
        ELSE 0
    END as unwind_amount
FROM tax_optimized_with_running_total
WHERE running_total - current_notional < 3000000
ORDER BY tax_priority, priority_rank;

-- 6. Unwind Impact Analysis - Compare All Methodologies
-- Shows tax impact of different unwind methodologies side by side
WITH methodology_comparison AS (
    -- LIFO Analysis
    SELECT 'LIFO' as methodology,
           SUM(CASE WHEN lifo_rank <= 2 THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END) as total_gain_loss,
           SUM(CASE WHEN lifo_rank <= 2 AND CURRENT_DATE - acquisition_date <= 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END) as short_term_gain_loss,
           SUM(CASE WHEN lifo_rank <= 2 AND CURRENT_DATE - acquisition_date > 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END) as long_term_gain_loss
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY acquisition_date DESC, acquisition_time DESC) as lifo_rank
        FROM TaxLot WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) lifo_lots
    
    UNION ALL
    
    -- FIFO Analysis  
    SELECT 'FIFO' as methodology,
           SUM(CASE WHEN fifo_rank <= 2 THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END),
           SUM(CASE WHEN fifo_rank <= 2 AND CURRENT_DATE - acquisition_date <= 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END),
           SUM(CASE WHEN fifo_rank <= 2 AND CURRENT_DATE - acquisition_date > 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END)
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY acquisition_date ASC, acquisition_time ASC) as fifo_rank
        FROM TaxLot WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) fifo_lots
    
    UNION ALL
    
    -- HICO Analysis
    SELECT 'HICO' as methodology,
           SUM(CASE WHEN hico_rank <= 2 THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END),
           SUM(CASE WHEN hico_rank <= 2 AND CURRENT_DATE - acquisition_date <= 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END),
           SUM(CASE WHEN hico_rank <= 2 AND CURRENT_DATE - acquisition_date > 365 
                    THEN (188.00 - cost_basis) * (current_notional / cost_basis) ELSE 0 END)
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY cost_basis DESC, acquisition_date ASC) as hico_rank
        FROM TaxLot WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) hico_lots
)
SELECT 
    methodology,
    ROUND(total_gain_loss, 2) as total_realized_gain_loss,
    ROUND(short_term_gain_loss, 2) as short_term_gain_loss,
    ROUND(long_term_gain_loss, 2) as long_term_gain_loss,
    ROUND(short_term_gain_loss * 0.37, 2) as estimated_short_term_tax, -- Assume 37% tax rate
    ROUND(long_term_gain_loss * 0.20, 2) as estimated_long_term_tax,   -- Assume 20% tax rate
    ROUND((short_term_gain_loss * 0.37) + (long_term_gain_loss * 0.20), 2) as total_estimated_tax
FROM methodology_comparison
ORDER BY total_estimated_tax ASC;

-- 7. Position Summary by Tax Lot
-- Current position view with unrealized P&L and tax implications
SELECT 
    tl.trade_id,
    tl.tax_lot_id,
    tl.lot_number,
    tl.acquisition_date,
    CURRENT_DATE - tl.acquisition_date as holding_period_days,
    
    -- Position details
    tl.current_notional,
    tl.current_shares,
    tl.cost_basis,
    tl.total_cost_basis,
    
    -- Current market value (assuming $188 current price)
    tl.current_shares * 188.00 as current_market_value,
    (tl.current_shares * 188.00) - tl.total_cost_basis as unrealized_gain_loss,
    
    -- Tax classification
    CASE 
        WHEN CURRENT_DATE - tl.acquisition_date > 365 THEN 'LONG_TERM'
        ELSE 'SHORT_TERM'
    END as tax_treatment,
    
    -- Lot status and availability
    tl.lot_status,
    CASE 
        WHEN tl.lot_status = 'OPEN' AND tl.current_notional > 0 THEN 'Available for Unwind'
        WHEN tl.lot_status = 'PARTIALLY_CLOSED' THEN 'Partially Unwound'
        ELSE 'Not Available'
    END as availability_status
    
FROM TaxLot tl
WHERE tl.trade_id = 'TRD001'
ORDER BY tl.acquisition_date, tl.lot_number;

-- 8. Wash Sale Detection and Impact
-- Identify potential wash sale situations during unwinds
WITH wash_sale_analysis AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.acquisition_date,
        tl.cost_basis,
        tl.current_notional,
        
        -- Look for substantially identical positions within 30 days
        COUNT(*) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.acquisition_date 
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND INTERVAL '30 days' FOLLOWING
        ) - 1 as potential_wash_sales,
        
        -- Check for losses that might be subject to wash sale rules
        CASE 
            WHEN 185.00 < tl.cost_basis THEN TRUE
            ELSE FALSE
        END as has_loss,
        
        (185.00 - tl.cost_basis) * tl.current_shares as potential_loss_amount
        
    FROM TaxLot tl
    WHERE tl.lot_status IN ('OPEN', 'PARTIALLY_CLOSED')
)
SELECT 
    tax_lot_id,
    acquisition_date,
    cost_basis,
    current_notional,
    has_loss,
    potential_loss_amount,
    potential_wash_sales,
    CASE 
        WHEN has_loss AND potential_wash_sales > 0 THEN 'WARN: Potential wash sale'
        WHEN has_loss THEN 'OK: Loss eligible for realization'
        ELSE 'N/A: Position has gain'
    END as wash_sale_status
FROM wash_sale_analysis
WHERE trade_id = 'TRD001'
ORDER BY acquisition_date;
