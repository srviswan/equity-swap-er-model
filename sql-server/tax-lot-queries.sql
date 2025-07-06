-- Tax Lot Methodology Query Examples (MS SQL Server)
-- Demonstrates various tax lot efficiency methods for equity swap unwinds
-- Converted from PostgreSQL to MS SQL Server syntax

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
        
        -- Calculate holding period for tax classification (SQL Server uses DATEDIFF)
        DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) as holding_period_days,
        CASE 
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) > 365 THEN 'LONG_TERM'
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
    tax_treatment,
    holding_period_days,
    fifo_rank,
    running_total
FROM fifo_lot_selection
WHERE running_total - current_notional < 5000000 -- $5M unwind example
ORDER BY fifo_rank;

-- 3. HICO (Highest Cost First) for Loss Harvesting
-- Select highest cost basis lots first to minimize gains
WITH hico_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.lot_number,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        
        -- Calculate potential gain/loss at current market price
        (195.50 - tl.cost_basis) * tl.current_shares as unrealized_pnl,
        (195.50 - tl.cost_basis) / tl.cost_basis * 100 as gain_loss_percent,
        
        -- Rank by highest cost basis first
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis DESC, tl.acquisition_date DESC
        ) as hico_rank,
        
        SUM(tl.current_notional) OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis DESC, tl.acquisition_date DESC
            ROWS UNBOUNDED PRECEDING
        ) as running_total
        
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
    FORMAT(unrealized_pnl, 'C', 'en-US') as potential_pnl,
    FORMAT(gain_loss_percent, 'N2') + '%' as gain_loss_percent,
    hico_rank,
    running_total
FROM hico_lot_selection
WHERE running_total - current_notional < 2000000 -- $2M unwind
ORDER BY hico_rank;

-- 4. LOCO (Lowest Cost First) for Gain Realization
-- Select lowest cost basis lots first to maximize gains
WITH loco_lot_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.lot_number,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        
        -- Calculate days held for tax treatment
        DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) as days_held,
        CASE 
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) > 365 THEN 'LONG_TERM'
            ELSE 'SHORT_TERM'
        END as tax_treatment,
        
        -- Potential gain at current market price
        (195.50 - tl.cost_basis) * tl.current_shares as potential_gain,
        
        ROW_NUMBER() OVER (
            PARTITION BY tl.trade_id 
            ORDER BY tl.cost_basis ASC, tl.acquisition_date ASC
        ) as loco_rank
        
    FROM TaxLot tl
    WHERE tl.lot_status = 'OPEN'
      AND tl.current_notional > 0
      AND tl.trade_id = 'TRD001'
      AND tl.cost_basis < 195.50 -- Only profitable lots
)
SELECT 
    tax_lot_id,
    lot_number,
    current_notional,
    cost_basis,
    tax_treatment,
    days_held,
    FORMAT(potential_gain, 'C', 'en-US') as potential_gain,
    loco_rank
FROM loco_lot_selection
ORDER BY loco_rank;

-- 5. Tax-Optimized Selection
-- Prioritize long-term losses, then short-term losses, then long-term gains
WITH tax_optimized_selection AS (
    SELECT 
        tl.tax_lot_id,
        tl.trade_id,
        tl.lot_number,
        tl.current_notional,
        tl.cost_basis,
        tl.acquisition_date,
        
        -- Tax classification
        CASE 
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) > 365 THEN 'LONG_TERM'
            ELSE 'SHORT_TERM'
        END as tax_treatment,
        
        -- Gain/Loss classification
        CASE 
            WHEN tl.cost_basis > 195.50 THEN 'LOSS'
            ELSE 'GAIN'
        END as gain_loss_type,
        
        -- Calculate potential P&L
        (195.50 - tl.cost_basis) * tl.current_shares as potential_pnl,
        
        -- Tax optimization priority
        CASE 
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) > 365 AND tl.cost_basis > 195.50 THEN 1 -- Long-term losses first
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) <= 365 AND tl.cost_basis > 195.50 THEN 2 -- Short-term losses second
            WHEN DATEDIFF(day, tl.acquisition_date, CAST(GETDATE() AS DATE)) > 365 AND tl.cost_basis <= 195.50 THEN 3 -- Long-term gains third
            ELSE 4 -- Short-term gains last
        END as tax_priority
        
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
    tax_treatment,
    gain_loss_type,
    FORMAT(potential_pnl, 'C', 'en-US') as potential_pnl,
    tax_priority,
    CASE tax_priority
        WHEN 1 THEN 'Long-term Loss (Optimal)'
        WHEN 2 THEN 'Short-term Loss (Good)'
        WHEN 3 THEN 'Long-term Gain (Acceptable)'
        WHEN 4 THEN 'Short-term Gain (Avoid if possible)'
    END as tax_efficiency_description
FROM tax_optimized_selection
ORDER BY tax_priority, cost_basis DESC; -- Within each priority, prefer higher cost basis

-- 6. Methodology Comparison Analysis
-- Compare the impact of different unwind methodologies
WITH methodology_comparison AS (
    SELECT 
        'LIFO' as methodology,
        SUM(CASE WHEN row_num <= 3 THEN (195.50 - cost_basis) * current_shares ELSE 0 END) as total_pnl,
        SUM(CASE WHEN row_num <= 3 THEN current_notional ELSE 0 END) as total_unwound,
        COUNT(CASE WHEN row_num <= 3 THEN 1 END) as lots_used
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY acquisition_date DESC) as row_num
        FROM TaxLot 
        WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) lifo_data
    
    UNION ALL
    
    SELECT 
        'FIFO' as methodology,
        SUM(CASE WHEN row_num <= 3 THEN (195.50 - cost_basis) * current_shares ELSE 0 END) as total_pnl,
        SUM(CASE WHEN row_num <= 3 THEN current_notional ELSE 0 END) as total_unwound,
        COUNT(CASE WHEN row_num <= 3 THEN 1 END) as lots_used
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY acquisition_date ASC) as row_num
        FROM TaxLot 
        WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) fifo_data
    
    UNION ALL
    
    SELECT 
        'HICO' as methodology,
        SUM(CASE WHEN row_num <= 3 THEN (195.50 - cost_basis) * current_shares ELSE 0 END) as total_pnl,
        SUM(CASE WHEN row_num <= 3 THEN current_notional ELSE 0 END) as total_unwound,
        COUNT(CASE WHEN row_num <= 3 THEN 1 END) as lots_used
    FROM (
        SELECT *, ROW_NUMBER() OVER (ORDER BY cost_basis DESC) as row_num
        FROM TaxLot 
        WHERE lot_status = 'OPEN' AND trade_id = 'TRD001'
    ) hico_data
)
SELECT 
    methodology,
    FORMAT(total_pnl, 'C', 'en-US') as realized_pnl,
    FORMAT(total_unwound, 'C', 'en-US') as amount_unwound,
    lots_used,
    RANK() OVER (ORDER BY total_pnl DESC) as pnl_rank
FROM methodology_comparison
ORDER BY total_pnl DESC;

-- 7. Wash Sale Detection Query
-- Identify potential wash sale violations (buy/sell same security within 30 days)
WITH wash_sale_analysis AS (
    SELECT 
        tl1.tax_lot_id as sell_lot_id,
        tl1.trade_id as sell_trade_id,
        tl1.acquisition_date as sell_date,
        tl2.tax_lot_id as buy_lot_id,
        tl2.trade_id as buy_trade_id,
        tl2.acquisition_date as buy_date,
        ABS(DATEDIFF(day, tl1.acquisition_date, tl2.acquisition_date)) as days_between,
        (tl1.cost_basis - 195.50) * tl1.current_shares as realized_loss
    FROM TaxLot tl1
    CROSS JOIN TaxLot tl2
    WHERE tl1.trade_id != tl2.trade_id  -- Different trades
      AND tl1.cost_basis > 195.50  -- Sell at a loss
      AND ABS(DATEDIFF(day, tl1.acquisition_date, tl2.acquisition_date)) <= 30  -- Within 30 days
      AND tl1.lot_status = 'OPEN'
      AND tl2.lot_status = 'OPEN'
)
SELECT 
    sell_lot_id,
    sell_trade_id,
    buy_lot_id,
    buy_trade_id,
    sell_date,
    buy_date,
    days_between,
    FORMAT(ABS(realized_loss), 'C', 'en-US') as potential_disallowed_loss,
    'WASH SALE RISK' as warning
FROM wash_sale_analysis
WHERE realized_loss < 0  -- Only losses subject to wash sale rules
ORDER BY days_between, ABS(realized_loss) DESC;
