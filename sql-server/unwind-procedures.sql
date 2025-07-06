-- Stored Procedures for Tax Lot Unwind Processing
-- Automated procedures to process trade unwinds using various tax lot methodologies
-- MS SQL Server Implementation

-- Stored procedure to execute unwind using specified methodology
CREATE PROCEDURE execute_tax_lot_unwind
    @p_trade_id VARCHAR(50),
    @p_unwind_notional DECIMAL(18,2),
    @p_methodology_id VARCHAR(50),
    @p_market_price DECIMAL(18,6),
    @p_unwind_date DATE = NULL,
    @p_processed_by VARCHAR(100) = 'SYSTEM'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @v_unwind_id VARCHAR(50);
    DECLARE @v_methodology_type VARCHAR(30);
    DECLARE @v_sort_criteria NVARCHAR(MAX);
    DECLARE @v_remaining_unwind DECIMAL(18,2);
    DECLARE @v_unwind_from_lot DECIMAL(18,2);
    DECLARE @v_total_unwound DECIMAL(18,2) = 0;
    DECLARE @v_lots_count INTEGER = 0;
    DECLARE @v_total_gain_loss DECIMAL(18,2) = 0;
    DECLARE @v_short_term_gain_loss DECIMAL(18,2) = 0;
    DECLARE @v_long_term_gain_loss DECIMAL(18,2) = 0;
    DECLARE @v_tax_impact NVARCHAR(MAX);
    DECLARE @v_selection_order INTEGER = 1;
    
    -- Set default unwind date if not provided
    IF @p_unwind_date IS NULL
        SET @p_unwind_date = CAST(GETDATE() AS DATE);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Generate unwind ID
        SET @v_unwind_id = 'UNW_' + FORMAT(GETDATE(), 'yyyyMMddHHmmss') + '_' + RIGHT(@p_trade_id, 3);
        
        -- Get methodology details
        SELECT @v_methodology_type = methodology_type, 
               @v_sort_criteria = sort_criteria
        FROM TaxLotUnwindMethodology 
        WHERE methodology_id = @p_methodology_id AND is_active = 1;
        
        IF @v_methodology_type IS NULL
        BEGIN
            RAISERROR('Invalid or inactive methodology: %s', 16, 1, @p_methodology_id);
            RETURN;
        END
        
        -- Create unwind header record
        INSERT INTO TaxLotUnwind (
            unwind_id, trade_id, requested_notional, unwind_date, unwind_time,
            methodology_id, market_price, unwind_status, processed_by, created_timestamp
        )
        VALUES (
            @v_unwind_id, @p_trade_id, @p_unwind_notional, @p_unwind_date, GETDATE(),
            @p_methodology_id, @p_market_price, 'PROCESSING', @p_processed_by, GETDATE()
        );
        
        SET @v_remaining_unwind = @p_unwind_notional;
        
        -- Process lots based on methodology
        DECLARE lot_cursor CURSOR FOR
        SELECT tax_lot_id, current_notional, cost_basis, 
               CASE 
                   WHEN DATEDIFF(DAY, acquisition_date, @p_unwind_date) >= 365 
                   THEN 'LONG_TERM' 
                   ELSE 'SHORT_TERM' 
               END as term_classification
        FROM TaxLot
        WHERE trade_id = @p_trade_id 
          AND lot_status IN ('OPEN', 'PARTIALLY_CLOSED')
          AND current_notional > 0
        ORDER BY 
            CASE @v_methodology_type
                WHEN 'LIFO' THEN acquisition_time
                WHEN 'FIFO' THEN acquisition_time
                WHEN 'HICO' THEN cost_basis
                WHEN 'LOCO' THEN cost_basis
            END DESC; -- Adjust ASC/DESC based on methodology
        
        DECLARE @lot_id VARCHAR(50), @lot_notional DECIMAL(18,2), @lot_cost DECIMAL(18,6), @term_class VARCHAR(20);
        
        OPEN lot_cursor;
        FETCH NEXT FROM lot_cursor INTO @lot_id, @lot_notional, @lot_cost, @term_class;
        
        WHILE @@FETCH_STATUS = 0 AND @v_remaining_unwind > 0
        BEGIN
            SET @v_unwind_from_lot = CASE 
                WHEN @lot_notional <= @v_remaining_unwind THEN @lot_notional
                ELSE @v_remaining_unwind
            END;
            
            -- Calculate gain/loss for this lot
            DECLARE @lot_gain_loss DECIMAL(18,2) = (@p_market_price - @lot_cost) * @v_unwind_from_lot;
            
            -- Insert unwind detail record
            INSERT INTO TaxLotUnwindDetail (
                unwind_id, tax_lot_id, unwind_notional, lot_cost_basis,
                market_price, gain_loss, term_classification, selection_order
            )
            VALUES (
                @v_unwind_id, @lot_id, @v_unwind_from_lot, @lot_cost,
                @p_market_price, @lot_gain_loss, @term_class, @v_selection_order
            );
            
            -- Update lot current notional
            UPDATE TaxLot 
            SET current_notional = current_notional - @v_unwind_from_lot,
                lot_status = CASE 
                    WHEN current_notional - @v_unwind_from_lot = 0 THEN 'FULLY_CLOSED'
                    ELSE 'PARTIALLY_CLOSED'
                END,
                last_updated = GETDATE()
            WHERE tax_lot_id = @lot_id;
            
            -- Accumulate totals
            SET @v_total_unwound = @v_total_unwound + @v_unwind_from_lot;
            SET @v_total_gain_loss = @v_total_gain_loss + @lot_gain_loss;
            SET @v_lots_count = @v_lots_count + 1;
            SET @v_remaining_unwind = @v_remaining_unwind - @v_unwind_from_lot;
            SET @v_selection_order = @v_selection_order + 1;
            
            IF @term_class = 'LONG_TERM'
                SET @v_long_term_gain_loss = @v_long_term_gain_loss + @lot_gain_loss;
            ELSE
                SET @v_short_term_gain_loss = @v_short_term_gain_loss + @lot_gain_loss;
            
            FETCH NEXT FROM lot_cursor INTO @lot_id, @lot_notional, @lot_cost, @term_class;
        END
        
        CLOSE lot_cursor;
        DEALLOCATE lot_cursor;
        
        -- Build tax impact summary
        SET @v_tax_impact = '{' +
            '"short_term_gain_loss": ' + CAST(@v_short_term_gain_loss AS VARCHAR(20)) + ',' +
            '"long_term_gain_loss": ' + CAST(@v_long_term_gain_loss AS VARCHAR(20)) + ',' +
            '"total_gain_loss": ' + CAST(@v_total_gain_loss AS VARCHAR(20)) + ',' +
            '"lots_processed": ' + CAST(@v_lots_count AS VARCHAR(10)) +
            '}';
        
        -- Update unwind header with final results
        UPDATE TaxLotUnwind
        SET actual_unwound_notional = @v_total_unwound,
            total_gain_loss = @v_total_gain_loss,
            short_term_gain_loss = @v_short_term_gain_loss,
            long_term_gain_loss = @v_long_term_gain_loss,
            tax_impact_summary = @v_tax_impact,
            unwind_status = CASE 
                WHEN @v_remaining_unwind > 0 THEN 'PARTIAL_COMPLETION'
                ELSE 'COMPLETED'
            END,
            completed_timestamp = GETDATE()
        WHERE unwind_id = @v_unwind_id;
        
        COMMIT TRANSACTION;
        
        -- Return results
        SELECT @v_unwind_id as unwind_id,
               @v_lots_count as lots_affected,
               @v_total_unwound as total_unwound,
               @v_total_gain_loss as realized_gain_loss,
               @v_tax_impact as tax_impact_summary;
               
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        -- Log error and re-throw
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
