-- Stored Procedures for Tax Lot Unwind Processing
-- Automated functions to process trade unwinds using various tax lot methodologies

-- Function to execute unwind using specified methodology
CREATE OR REPLACE FUNCTION execute_tax_lot_unwind(
    p_trade_id VARCHAR(50),
    p_unwind_notional DECIMAL(18,2),
    p_methodology_id VARCHAR(50),
    p_market_price DECIMAL(18,6),
    p_unwind_date DATE DEFAULT CURRENT_DATE,
    p_processed_by VARCHAR(100) DEFAULT 'SYSTEM'
)
RETURNS TABLE (
    unwind_id VARCHAR(50),
    lots_affected INTEGER,
    total_unwound DECIMAL(18,2),
    realized_gain_loss DECIMAL(18,2),
    tax_impact_summary JSONB
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_unwind_id VARCHAR(50);
    v_methodology_type VARCHAR(30);
    v_sort_criteria JSONB;
    v_lot_record RECORD;
    v_remaining_unwind DECIMAL(18,2);
    v_unwind_from_lot DECIMAL(18,2);
    v_total_unwound DECIMAL(18,2) := 0;
    v_lots_count INTEGER := 0;
    v_total_gain_loss DECIMAL(18,2) := 0;
    v_short_term_gain_loss DECIMAL(18,2) := 0;
    v_long_term_gain_loss DECIMAL(18,2) := 0;
    v_tax_impact JSONB;
    v_selection_order INTEGER := 1;
BEGIN
    -- Generate unwind ID
    v_unwind_id := 'UNW_' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS') || '_' || RIGHT(p_trade_id, 3);
    
    -- Get methodology details
    SELECT methodology_type, sort_criteria 
    INTO v_methodology_type, v_sort_criteria
    FROM TaxLotUnwindMethodology 
    WHERE methodology_id = p_methodology_id AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or inactive methodology: %', p_methodology_id;
    END IF;
    
    -- Create unwind header record
    INSERT INTO TaxLotUnwind (
        unwind_id, trade_id, requested_notional, unwind_date, unwind_time,
        methodology_id, unwind_status, processed_by
    ) VALUES (
        v_unwind_id, p_trade_id, p_unwind_notional, p_unwind_date, CURRENT_TIMESTAMP,
        p_methodology_id, 'IN_PROGRESS', p_processed_by
    );
    
    -- Initialize remaining amount to unwind
    v_remaining_unwind := p_unwind_notional;
    
    -- Process lots based on methodology
    FOR v_lot_record IN
        SELECT tax_lot_id, current_notional, current_shares, cost_basis, total_cost_basis,
               acquisition_date, holding_period_start_date
        FROM TaxLot tl
        WHERE tl.trade_id = p_trade_id 
          AND tl.lot_status = 'OPEN' 
          AND tl.current_notional > 0
        ORDER BY 
            CASE 
                WHEN v_methodology_type = 'LIFO' THEN tl.acquisition_date END DESC,
            CASE 
                WHEN v_methodology_type = 'FIFO' THEN tl.acquisition_date END ASC,
            CASE 
                WHEN v_methodology_type = 'HICO' THEN tl.cost_basis END DESC,
            CASE 
                WHEN v_methodology_type = 'LOCO' THEN tl.cost_basis END ASC,
            tl.acquisition_time
    LOOP
        EXIT WHEN v_remaining_unwind <= 0;
        
        -- Calculate amount to unwind from this lot
        v_unwind_from_lot := LEAST(v_lot_record.current_notional, v_remaining_unwind);
        
        -- Insert unwind detail record
        INSERT INTO TaxLotUnwindDetail (
            unwind_detail_id, unwind_id, tax_lot_id,
            unwound_notional, unwound_shares, unwind_percentage,
            cost_basis_per_unit, total_cost_basis,
            market_value_per_unit, total_market_value, realized_gain_loss,
            holding_period_days, tax_classification,
            selection_order, selection_criteria,
            unwind_price, unwind_timestamp
        ) VALUES (
            v_unwind_id || '_DTL_' || LPAD(v_selection_order::TEXT, 3, '0'),
            v_unwind_id,
            v_lot_record.tax_lot_id,
            v_unwind_from_lot,
            v_unwind_from_lot / v_lot_record.cost_basis, -- Approximate shares
            v_unwind_from_lot / v_lot_record.current_notional,
            v_lot_record.cost_basis,
            v_lot_record.total_cost_basis * (v_unwind_from_lot / v_lot_record.current_notional),
            p_market_price,
            (v_unwind_from_lot / v_lot_record.cost_basis) * p_market_price,
            ((v_unwind_from_lot / v_lot_record.cost_basis) * p_market_price) - 
                (v_lot_record.total_cost_basis * (v_unwind_from_lot / v_lot_record.current_notional)),
            p_unwind_date - v_lot_record.holding_period_start_date,
            CASE WHEN p_unwind_date - v_lot_record.holding_period_start_date > 365 
                 THEN 'LONG_TERM' ELSE 'SHORT_TERM' END,
            v_selection_order,
            jsonb_build_object(
                'methodology', v_methodology_type,
                'cost_basis', v_lot_record.cost_basis,
                'acquisition_date', v_lot_record.acquisition_date
            ),
            p_market_price,
            CURRENT_TIMESTAMP
        );
        
        -- Update lot status
        UPDATE TaxLot 
        SET current_notional = current_notional - v_unwind_from_lot,
            current_shares = current_shares - (v_unwind_from_lot / cost_basis),
            lot_status = CASE 
                WHEN current_notional - v_unwind_from_lot <= 0 THEN 'FULLY_CLOSED'
                ELSE 'PARTIALLY_CLOSED'
            END,
            last_updated = CURRENT_TIMESTAMP
        WHERE tax_lot_id = v_lot_record.tax_lot_id;
        
        -- Update totals
        v_remaining_unwind := v_remaining_unwind - v_unwind_from_lot;
        v_total_unwound := v_total_unwound + v_unwind_from_lot;
        v_lots_count := v_lots_count + 1;
        v_selection_order := v_selection_order + 1;
        
        -- Calculate gain/loss
        DECLARE
            v_lot_gain_loss DECIMAL(18,2);
            v_holding_days INTEGER;
        BEGIN
            v_lot_gain_loss := ((v_unwind_from_lot / v_lot_record.cost_basis) * p_market_price) - 
                              (v_lot_record.total_cost_basis * (v_unwind_from_lot / v_lot_record.current_notional));
            v_holding_days := p_unwind_date - v_lot_record.holding_period_start_date;
            
            v_total_gain_loss := v_total_gain_loss + v_lot_gain_loss;
            
            IF v_holding_days > 365 THEN
                v_long_term_gain_loss := v_long_term_gain_loss + v_lot_gain_loss;
            ELSE
                v_short_term_gain_loss := v_short_term_gain_loss + v_lot_gain_loss;
            END IF;
        END;
    END LOOP;
    
    -- Build tax impact summary
    v_tax_impact := jsonb_build_object(
        'total_realized_gain_loss', v_total_gain_loss,
        'short_term_gain_loss', v_short_term_gain_loss,
        'long_term_gain_loss', v_long_term_gain_loss,
        'estimated_tax_impact', jsonb_build_object(
            'short_term_tax', v_short_term_gain_loss * 0.37,
            'long_term_tax', v_long_term_gain_loss * 0.20,
            'total_estimated_tax', (v_short_term_gain_loss * 0.37) + (v_long_term_gain_loss * 0.20)
        ),
        'methodology_used', v_methodology_type,
        'unwind_efficiency', CASE 
            WHEN v_total_unwound >= p_unwind_notional THEN 'COMPLETE'
            ELSE 'PARTIAL'
        END
    );
    
    -- Update unwind header with final results
    UPDATE TaxLotUnwind 
    SET total_unwound_notional = v_total_unwound,
        lots_affected_count = v_lots_count,
        total_realized_gain_loss = v_total_gain_loss,
        short_term_gain_loss = v_short_term_gain_loss,
        long_term_gain_loss = v_long_term_gain_loss,
        unwind_status = CASE 
            WHEN v_total_unwound >= p_unwind_notional THEN 'COMPLETED'
            ELSE 'PARTIAL'
        END,
        completed_timestamp = CURRENT_TIMESTAMP,
        processing_notes = 'Unwind processed using ' || v_methodology_type || ' methodology'
    WHERE unwind_id = v_unwind_id;
    
    -- Return results
    RETURN QUERY
    SELECT v_unwind_id, v_lots_count, v_total_unwound, v_total_gain_loss, v_tax_impact;
    
END;
$$;

-- Function to compare unwind methodologies before execution
CREATE OR REPLACE FUNCTION compare_unwind_methodologies(
    p_trade_id VARCHAR(50),
    p_unwind_notional DECIMAL(18,2),
    p_market_price DECIMAL(18,6)
)
RETURNS TABLE (
    methodology VARCHAR(30),
    total_gain_loss DECIMAL(18,2),
    short_term_gain_loss DECIMAL(18,2),
    long_term_gain_loss DECIMAL(18,2),
    estimated_tax_impact DECIMAL(18,2),
    lots_required INTEGER,
    methodology_rank INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH methodology_analysis AS (
        -- LIFO Analysis
        SELECT 'LIFO'::VARCHAR(30) as method,
               calc_methodology_impact(p_trade_id, p_unwind_notional, p_market_price, 'LIFO') as impact
        UNION ALL
        -- FIFO Analysis  
        SELECT 'FIFO'::VARCHAR(30),
               calc_methodology_impact(p_trade_id, p_unwind_notional, p_market_price, 'FIFO')
        UNION ALL
        -- HICO Analysis
        SELECT 'HICO'::VARCHAR(30),
               calc_methodology_impact(p_trade_id, p_unwind_notional, p_market_price, 'HICO')
        UNION ALL
        -- LOCO Analysis
        SELECT 'LOCO'::VARCHAR(30),
               calc_methodology_impact(p_trade_id, p_unwind_notional, p_market_price, 'LOCO')
    )
    SELECT 
        ma.method,
        (ma.impact->>'total_gain_loss')::DECIMAL(18,2),
        (ma.impact->>'short_term_gain_loss')::DECIMAL(18,2),
        (ma.impact->>'long_term_gain_loss')::DECIMAL(18,2),
        (ma.impact->>'estimated_tax_impact')::DECIMAL(18,2),
        (ma.impact->>'lots_required')::INTEGER,
        ROW_NUMBER() OVER (ORDER BY (ma.impact->>'estimated_tax_impact')::DECIMAL(18,2)) as rank
    FROM methodology_analysis ma
    ORDER BY (ma.impact->>'estimated_tax_impact')::DECIMAL(18,2);
END;
$$;

-- Helper function to calculate methodology impact (simplified version)
CREATE OR REPLACE FUNCTION calc_methodology_impact(
    p_trade_id VARCHAR(50),
    p_unwind_notional DECIMAL(18,2),
    p_market_price DECIMAL(18,6),
    p_methodology VARCHAR(30)
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
    v_running_total DECIMAL(18,2) := 0;
    v_total_gain_loss DECIMAL(18,2) := 0;
    v_short_term_gain_loss DECIMAL(18,2) := 0;
    v_long_term_gain_loss DECIMAL(18,2) := 0;
    v_lots_count INTEGER := 0;
    v_lot_record RECORD;
    v_unwind_amount DECIMAL(18,2);
    v_lot_gain_loss DECIMAL(18,2);
BEGIN
    -- Process lots based on methodology ordering
    FOR v_lot_record IN
        SELECT tax_lot_id, current_notional, cost_basis, acquisition_date, holding_period_start_date
        FROM TaxLot 
        WHERE trade_id = p_trade_id AND lot_status = 'OPEN' AND current_notional > 0
        ORDER BY 
            CASE WHEN p_methodology = 'LIFO' THEN acquisition_date END DESC,
            CASE WHEN p_methodology = 'FIFO' THEN acquisition_date END ASC,
            CASE WHEN p_methodology = 'HICO' THEN cost_basis END DESC,
            CASE WHEN p_methodology = 'LOCO' THEN cost_basis END ASC
    LOOP
        EXIT WHEN v_running_total >= p_unwind_notional;
        
        -- Calculate unwind amount from this lot
        v_unwind_amount := LEAST(v_lot_record.current_notional, p_unwind_notional - v_running_total);
        
        -- Calculate gain/loss for this portion
        v_lot_gain_loss := ((v_unwind_amount / v_lot_record.cost_basis) * p_market_price) - v_unwind_amount;
        
        v_total_gain_loss := v_total_gain_loss + v_lot_gain_loss;
        v_running_total := v_running_total + v_unwind_amount;
        v_lots_count := v_lots_count + 1;
        
        -- Classify as short-term vs long-term
        IF CURRENT_DATE - v_lot_record.holding_period_start_date > 365 THEN
            v_long_term_gain_loss := v_long_term_gain_loss + v_lot_gain_loss;
        ELSE
            v_short_term_gain_loss := v_short_term_gain_loss + v_lot_gain_loss;
        END IF;
    END LOOP;
    
    -- Build result JSON
    v_result := jsonb_build_object(
        'total_gain_loss', v_total_gain_loss,
        'short_term_gain_loss', v_short_term_gain_loss,
        'long_term_gain_loss', v_long_term_gain_loss,
        'estimated_tax_impact', (v_short_term_gain_loss * 0.37) + (v_long_term_gain_loss * 0.20),
        'lots_required', v_lots_count,
        'methodology', p_methodology
    );
    
    RETURN v_result;
END;
$$;

-- Example usage and testing queries
-- Test the unwind function with different methodologies

-- 1. Execute HICO unwind to minimize gains
/*
SELECT * FROM execute_tax_lot_unwind(
    'TRD001',              -- trade_id
    3000000.00,            -- unwind_notional  
    'METH_HICO',           -- methodology_id
    188.50,                -- market_price
    CURRENT_DATE,          -- unwind_date
    'TRADER_JOHN'          -- processed_by
);
*/

-- 2. Compare all methodologies before unwinding
/*
SELECT * FROM compare_unwind_methodologies(
    'TRD001',              -- trade_id
    3000000.00,            -- unwind_notional
    188.50                 -- market_price
);
*/

-- 3. View unwind history with details
/*
SELECT 
    tu.unwind_id,
    tu.trade_id,
    tu.unwind_date,
    tm.methodology_name,
    tu.requested_notional,
    tu.total_unwound_notional,
    tu.lots_affected_count,
    tu.total_realized_gain_loss,
    tu.unwind_status
FROM TaxLotUnwind tu
JOIN TaxLotUnwindMethodology tm ON tu.methodology_id = tm.methodology_id
WHERE tu.trade_id = 'TRD001'
ORDER BY tu.unwind_date DESC;
*/
