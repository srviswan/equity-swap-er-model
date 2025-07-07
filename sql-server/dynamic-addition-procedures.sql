-- Dynamic Basket Addition Stored Procedures
-- Comprehensive procedures for managing dynamic underlier additions
-- Microsoft SQL Server Implementation

-- =============================================================================
-- PROCEDURE 1: REQUEST DYNAMIC UNDERLIER ADDITION
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_RequestDynamicUnderlierAddition
    @group_id VARCHAR(50),
    @new_underlier_symbol VARCHAR(20),
    @new_underlier_name VARCHAR(200),
    @new_underlier_sector VARCHAR(50),
    @new_underlier_country CHAR(3),
    @target_weight_pct DECIMAL(8,4), -- Percentage (e.g., 12.50 for 12.5%)
    @addition_source VARCHAR(50),
    @addition_rationale NVARCHAR(MAX),
    @execution_priority VARCHAR(10) = 'MEDIUM',
    @weight_rebalance_method VARCHAR(30) = 'PRO_RATA_REDUCTION',
    @requested_by VARCHAR(100),
    @addition_id VARCHAR(50) OUTPUT,
    @version_id VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @target_weight DECIMAL(10,6);
    DECLARE @target_total_notional DECIMAL(18,2);
    DECLARE @target_notional DECIMAL(18,2);
    DECLARE @current_version_number INT;
    DECLARE @new_version_number INT;
    DECLARE @current_composition NVARCHAR(MAX);
    DECLARE @new_composition NVARCHAR(MAX);
    DECLARE @affected_positions NVARCHAR(MAX);
    DECLARE @rebalance_trades_count INT;
    DECLARE @expected_turnover DECIMAL(8,4);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Convert percentage to decimal
        SET @target_weight = @target_weight_pct / 100.0;
        
        -- Validate inputs
        IF NOT EXISTS (SELECT 1 FROM TradeGroup WHERE group_id = @group_id AND group_type = 'BASKET_STRATEGY')
        BEGIN
            RAISERROR('Invalid basket group ID or group is not a basket strategy', 16, 1);
            RETURN;
        END
        
        IF @target_weight <= 0 OR @target_weight >= 1
        BEGIN
            RAISERROR('Target weight must be between 0% and 100%', 16, 1);
            RETURN;
        END
        
        -- Get current basket information
        SELECT 
            @target_total_notional = target_total_notional
        FROM TradeGroup 
        WHERE group_id = @group_id;
        
        -- Calculate target notional for new position
        SET @target_notional = @target_total_notional * @target_weight;
        
        -- Get current active version
        SELECT 
            @current_version_number = version_number,
            @current_composition = target_composition
        FROM BasketCompositionVersion 
        WHERE group_id = @group_id AND version_status = 'ACTIVE';
        
        -- Calculate new version number
        SET @new_version_number = ISNULL(@current_version_number, 0) + 1;
        
        -- Generate IDs
        SET @addition_id = 'ADD_' + @new_underlier_symbol + '_' + FORMAT(GETDATE(), 'yyyyMMddHHmm');
        SET @version_id = 'VER_' + @group_id + '_V' + CAST(@new_version_number AS VARCHAR(10));
        
        -- Calculate new composition with pro-rata reduction
        -- This is a simplified calculation - in practice, you'd want more sophisticated rebalancing logic
        DECLARE @reduction_factor DECIMAL(10,6) = 1.0 - @target_weight;
        
        -- Build new composition JSON (simplified - assumes current composition is properly formatted)
        -- In production, you would parse the JSON and recalculate each position
        SET @new_composition = JSON_MODIFY(@current_composition, 
            'append $', 
            JSON_OBJECT(@new_underlier_symbol, @target_weight_pct));
        
        -- Calculate affected positions and rebalancing requirements
        -- Count positions that need reduction
        SELECT @rebalance_trades_count = COUNT(*) + 1 -- +1 for the new buy
        FROM OPENJSON(@current_composition);
        
        -- Estimate turnover (simplified calculation)
        SET @expected_turnover = @target_weight_pct * 2; -- Buy new + sell others
        
        -- Create new composition version
        INSERT INTO BasketCompositionVersion (
            version_id, group_id, version_number, version_type,
            target_composition, previous_composition,
            change_reason, change_requested_by, expected_turnover_pct,
            version_status
        ) VALUES (
            @version_id, @group_id, @new_version_number, 'ADDITION',
            @new_composition, @current_composition,
            @addition_rationale, @requested_by, @expected_turnover,
            'PENDING'
        );
        
        -- Create dynamic addition request
        INSERT INTO DynamicUnderlierAddition (
            addition_id, group_id, version_id, new_underlier_symbol, 
            new_underlier_name, new_underlier_sector, new_underlier_country,
            target_weight, target_notional, addition_source, addition_rationale,
            execution_priority, weight_rebalance_method, rebalance_trades_required,
            addition_status, requested_by, requested_date
        ) VALUES (
            @addition_id, @group_id, @version_id, @new_underlier_symbol,
            @new_underlier_name, @new_underlier_sector, @new_underlier_country,
            @target_weight, @target_notional, @addition_source, @addition_rationale,
            @execution_priority, @weight_rebalance_method, @rebalance_trades_count,
            'REQUESTED', @requested_by, GETDATE()
        );
        
        COMMIT TRANSACTION;
        
        -- Return success message
        SELECT 
            'SUCCESS' as Status,
            @addition_id as AdditionId,
            @version_id as VersionId,
            'Dynamic addition request created successfully' as Message;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

-- =============================================================================
-- PROCEDURE 2: APPROVE DYNAMIC ADDITION
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_ApproveDynamicAddition
    @addition_id VARCHAR(50),
    @approved_by VARCHAR(100),
    @approval_notes NVARCHAR(MAX) = NULL,
    @create_workflow BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @group_id VARCHAR(50);
    DECLARE @version_id VARCHAR(50);
    DECLARE @workflow_id VARCHAR(50);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate addition request exists and is in correct status
        IF NOT EXISTS (
            SELECT 1 FROM DynamicUnderlierAddition 
            WHERE addition_id = @addition_id 
            AND addition_status IN ('REQUESTED', 'UNDER_REVIEW')
        )
        BEGIN
            RAISERROR('Addition request not found or not in valid status for approval', 16, 1);
            RETURN;
        END
        
        -- Get request details
        SELECT 
            @group_id = group_id,
            @version_id = version_id
        FROM DynamicUnderlierAddition 
        WHERE addition_id = @addition_id;
        
        -- Update addition status
        UPDATE DynamicUnderlierAddition 
        SET 
            addition_status = 'APPROVED',
            reviewed_by = @approved_by,
            review_date = GETDATE(),
            review_notes = @approval_notes
        WHERE addition_id = @addition_id;
        
        -- Update version status
        UPDATE BasketCompositionVersion
        SET 
            version_status = 'APPROVED',
            change_approved_by = @approved_by,
            change_approval_date = GETDATE()
        WHERE version_id = @version_id;
        
        -- Create rebalancing workflow if requested
        IF @create_workflow = 1
        BEGIN
            SET @workflow_id = 'WF_' + @addition_id;
            
            DECLARE @total_trades INT;
            SELECT @total_trades = rebalance_trades_required 
            FROM DynamicUnderlierAddition 
            WHERE addition_id = @addition_id;
            
            INSERT INTO RebalancingWorkflow (
                workflow_id, group_id, version_id, workflow_type,
                total_trades_required, execution_strategy, execution_urgency,
                workflow_status, created_by
            ) VALUES (
                @workflow_id, @group_id, @version_id, 'ADDITION_REBALANCE',
                @total_trades, 'IMPLEMENTATION_SHORTFALL', 'NORMAL',
                'PLANNED', @approved_by
            );
        END
        
        COMMIT TRANSACTION;
        
        -- Return success message
        SELECT 
            'SUCCESS' as Status,
            @addition_id as AdditionId,
            @workflow_id as WorkflowId,
            'Dynamic addition approved successfully' as Message;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

-- =============================================================================
-- PROCEDURE 3: GENERATE REBALANCING TRADES
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_GenerateRebalancingTrades
    @workflow_id VARCHAR(50),
    @execution_start_sequence INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @group_id VARCHAR(50);
    DECLARE @version_id VARCHAR(50);
    DECLARE @addition_id VARCHAR(50);
    DECLARE @current_sequence INT = @execution_start_sequence;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get workflow details
        SELECT 
            @group_id = group_id,
            @version_id = version_id
        FROM RebalancingWorkflow 
        WHERE workflow_id = @workflow_id;
        
        -- Get associated addition
        SELECT 
            @addition_id = addition_id
        FROM DynamicUnderlierAddition 
        WHERE group_id = @group_id AND version_id = @version_id;
        
        -- Get addition details
        DECLARE @new_symbol VARCHAR(20);
        DECLARE @target_weight DECIMAL(10,6);
        DECLARE @target_notional DECIMAL(18,2);
        DECLARE @total_notional DECIMAL(18,2);
        
        SELECT 
            @new_symbol = new_underlier_symbol,
            @target_weight = target_weight,
            @target_notional = target_notional
        FROM DynamicUnderlierAddition 
        WHERE addition_id = @addition_id;
        
        SELECT @total_notional = target_total_notional 
        FROM TradeGroup 
        WHERE group_id = @group_id;
        
        -- Create new position trade (BUY)
        INSERT INTO RebalancingTrade (
            rebalancing_trade_id, workflow_id, underlier_symbol, trade_type, side,
            target_notional, target_weight_change, current_weight, target_weight,
            weight_adjustment, execution_sequence, execution_status
        ) VALUES (
            'RBT_' + @new_symbol + '_BUY_' + FORMAT(GETDATE(), 'yyyyMMddHHmm'),
            @workflow_id, @new_symbol, 'NEW_ADDITION', 'BUY',
            @target_notional, @target_weight, 0.0, @target_weight,
            @target_weight, @current_sequence, 'PENDING'
        );
        
        SET @current_sequence = @current_sequence + 1;
        
        -- Get current composition and create reduction trades
        DECLARE @current_composition NVARCHAR(MAX);
        SELECT @current_composition = target_composition 
        FROM BasketCompositionVersion 
        WHERE group_id = @group_id AND version_status = 'ACTIVE';
        
        -- Create cursor for existing positions that need reduction
        DECLARE position_cursor CURSOR FOR
        SELECT [key] as symbol, CAST([value] AS DECIMAL(10,6)) as current_weight_pct
        FROM OPENJSON(@current_composition);
        
        DECLARE @symbol VARCHAR(20);
        DECLARE @current_weight_pct DECIMAL(10,6);
        DECLARE @reduction_factor DECIMAL(10,6) = 1.0 - @target_weight;
        
        OPEN position_cursor;
        FETCH NEXT FROM position_cursor INTO @symbol, @current_weight_pct;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @new_weight_pct DECIMAL(10,6) = @current_weight_pct * @reduction_factor;
            DECLARE @weight_change DECIMAL(10,6) = @new_weight_pct - @current_weight_pct;
            DECLARE @reduction_notional DECIMAL(18,2) = ABS(@weight_change) * @total_notional / 100.0;
            
            -- Create reduction trade (SELL)
            INSERT INTO RebalancingTrade (
                rebalancing_trade_id, workflow_id, underlier_symbol, trade_type, side,
                target_notional, target_weight_change, current_weight, target_weight,
                weight_adjustment, execution_sequence, execution_status
            ) VALUES (
                'RBT_' + @symbol + '_SELL_' + FORMAT(GETDATE(), 'yyyyMMddHHmm'),
                @workflow_id, @symbol, 'WEIGHT_DECREASE', 'SELL',
                @reduction_notional, @weight_change, @current_weight_pct / 100.0, @new_weight_pct / 100.0,
                @weight_change, @current_sequence, 'PENDING'
            );
            
            SET @current_sequence = @current_sequence + 1;
            
            FETCH NEXT FROM position_cursor INTO @symbol, @current_weight_pct;
        END
        
        CLOSE position_cursor;
        DEALLOCATE position_cursor;
        
        -- Update workflow status
        UPDATE RebalancingWorkflow 
        SET workflow_status = 'APPROVED'
        WHERE workflow_id = @workflow_id;
        
        COMMIT TRANSACTION;
        
        -- Return summary
        SELECT 
            'SUCCESS' as Status,
            @workflow_id as WorkflowId,
            (@current_sequence - @execution_start_sequence) as TradesGenerated,
            'Rebalancing trades generated successfully' as Message;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

-- =============================================================================
-- PROCEDURE 4: COMPLETE DYNAMIC ADDITION
-- =============================================================================

CREATE OR ALTER PROCEDURE sp_CompleteDynamicAddition
    @workflow_id VARCHAR(50),
    @completed_by VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @group_id VARCHAR(50);
    DECLARE @version_id VARCHAR(50);
    DECLARE @addition_id VARCHAR(50);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get workflow details
        SELECT 
            @group_id = group_id,
            @version_id = version_id
        FROM RebalancingWorkflow 
        WHERE workflow_id = @workflow_id;
        
        -- Get addition ID
        SELECT @addition_id = addition_id
        FROM DynamicUnderlierAddition 
        WHERE group_id = @group_id AND version_id = @version_id;
        
        -- Verify all trades are completed
        IF EXISTS (
            SELECT 1 FROM RebalancingTrade 
            WHERE workflow_id = @workflow_id 
            AND execution_status NOT IN ('FILLED', 'CANCELLED')
        )
        BEGIN
            RAISERROR('Cannot complete addition - not all trades are filled or cancelled', 16, 1);
            RETURN;
        END
        
        -- Deactivate current version
        UPDATE BasketCompositionVersion 
        SET version_status = 'SUPERSEDED'
        WHERE group_id = @group_id AND version_status = 'ACTIVE';
        
        -- Activate new version
        UPDATE BasketCompositionVersion 
        SET 
            version_status = 'ACTIVE',
            activated_timestamp = GETDATE(),
            effective_date = GETDATE()
        WHERE version_id = @version_id;
        
        -- Update addition status
        UPDATE DynamicUnderlierAddition 
        SET addition_status = 'COMPLETED'
        WHERE addition_id = @addition_id;
        
        -- Update workflow status
        UPDATE RebalancingWorkflow 
        SET 
            workflow_status = 'COMPLETED',
            actual_end_time = GETDATE(),
            completion_percentage = 100.0
        WHERE workflow_id = @workflow_id;
        
        -- Create history record
        DECLARE @new_composition NVARCHAR(MAX);
        DECLARE @old_composition NVARCHAR(MAX);
        
        SELECT @new_composition = target_composition 
        FROM BasketCompositionVersion 
        WHERE version_id = @version_id;
        
        SELECT @old_composition = target_composition 
        FROM BasketCompositionVersion 
        WHERE group_id = @group_id AND version_status = 'SUPERSEDED';
        
        INSERT INTO BasketCompositionHistory (
            history_id, group_id, change_date, change_type,
            composition_before, composition_after,
            initiated_by, executed_by, change_reason
        ) VALUES (
            'HIST_' + @addition_id,
            @group_id, GETDATE(), 'ADDITION',
            @old_composition, @new_composition,
            (SELECT requested_by FROM DynamicUnderlierAddition WHERE addition_id = @addition_id),
            @completed_by,
            'Dynamic addition completed via workflow ' + @workflow_id
        );
        
        COMMIT TRANSACTION;
        
        -- Return success message
        SELECT 
            'SUCCESS' as Status,
            @addition_id as AdditionId,
            @workflow_id as WorkflowId,
            'Dynamic addition completed successfully' as Message;
            
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

-- =============================================================================
-- EXAMPLE USAGE
-- =============================================================================

/*
-- Example 1: Request addition of new underlier
DECLARE @addition_id VARCHAR(50), @version_id VARCHAR(50);
EXEC sp_RequestDynamicUnderlierAddition
    @group_id = 'GRP_TECH_BASKET_001',
    @new_underlier_symbol = 'CRM',
    @new_underlier_name = 'Salesforce Inc',
    @new_underlier_sector = 'Technology',
    @new_underlier_country = 'USA',
    @target_weight_pct = 8.5,
    @addition_source = 'STRATEGIC_DECISION',
    @addition_rationale = 'Add CRM for cloud software exposure and diversification',
    @execution_priority = 'HIGH',
    @requested_by = 'PORTFOLIO_MANAGER_002',
    @addition_id = @addition_id OUTPUT,
    @version_id = @version_id OUTPUT;

-- Example 2: Approve the addition
EXEC sp_ApproveDynamicAddition
    @addition_id = @addition_id,
    @approved_by = 'RISK_MANAGER_001',
    @approval_notes = 'Approved after risk review - within concentration limits',
    @create_workflow = 1;

-- Example 3: Generate rebalancing trades
DECLARE @workflow_id VARCHAR(50) = 'WF_' + @addition_id;
EXEC sp_GenerateRebalancingTrades
    @workflow_id = @workflow_id;

-- Example 4: Complete the addition (after trades execute)
EXEC sp_CompleteDynamicAddition
    @workflow_id = @workflow_id,
    @completed_by = 'EXECUTION_TRADER_001';
*/
