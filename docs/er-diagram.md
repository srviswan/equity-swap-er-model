# Equity Swap Management System - ER Diagram

## Overview

This ER diagram represents the core entities and relationships required for managing equity swap trades throughout their lifecycle, based on the FINOS CDM specification.

## Core Entities

### 1. Trade
**Primary Entity** - Represents an equity swap transaction
- **Attributes:**
  - `trade_id` (PK) - Unique identifier
  - `trade_date` - Date when trade was agreed
  - `trade_time` - Time and timezone of trade
  - `status` - Current trade status (Active, Terminated, etc.)
  - `created_timestamp` - System creation time
  - `updated_timestamp` - Last update time

### 2. TradeState
**State Management** - Tracks the current state of a trade
- **Attributes:**
  - `trade_state_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `state_timestamp` - When this state became effective
  - `state_type` - Type of state (Execution, Reset, Termination, etc.)
  - `is_current` - Boolean indicating if this is the current state

### 3. TradableProduct
**Product Definition** - Defines the tradable equity swap product
- **Attributes:**
  - `product_id` (PK) - Unique identifier
  - `product_type` - Type of equity swap (Price Return, Total Return, etc.)
  - `created_date` - Product creation date
  - `version` - Product version number

### 4. EconomicTerms
**Contract Terms** - Defines the economic terms of the swap
- **Attributes:**
  - `economic_terms_id` (PK) - Unique identifier
  - `product_id` (FK) - Reference to TradableProduct
  - `effective_date` - Start date of the terms
  - `termination_date` - End date of the terms
  - `calculation_agent_id` (FK) - Reference to calculation agent party

### 5. Payout
**Cash Flow Definition** - Defines payout calculations
- **Attributes:**
  - `payout_id` (PK) - Unique identifier
  - `economic_terms_id` (FK) - Reference to EconomicTerms
  - `payout_type` - Type (PerformancePayout, InterestRatePayout)
  - `payer_party_id` (FK) - Reference to paying party
  - `receiver_party_id` (FK) - Reference to receiving party

### 6. PerformancePayout
**Equity Performance** - Specific to equity performance calculations
- **Attributes:**
  - `performance_payout_id` (PK) - Unique identifier
  - `payout_id` (FK) - Reference to base Payout
  - `underlier_id` (FK) - Reference to underlying asset
  - `return_type` - Price, Total, Variance, Volatility
  - `initial_price` - Starting price for calculation
  - `notional_amount` - Notional amount

### 7. Underlier
**Underlying Assets** - Assets underlying the equity swap
- **Attributes:**
  - `underlier_id` (PK) - Unique identifier
  - `asset_type` - Single stock, index, basket
  - `identifier` - Asset identifier (ISIN, ticker, etc.)
  - `identifier_type` - Type of identifier
  - `name` - Asset name
  - `currency` - Asset currency

### 8. Party
**Parties** - All parties involved in trades
- **Attributes:**
  - `party_id` (PK) - Unique identifier
  - `party_name` - Legal name
  - `party_type` - Legal entity type
  - `lei_code` - Legal Entity Identifier
  - `country` - Country of incorporation

### 9. PartyRole
**Role Assignment** - Roles parties play in trades
- **Attributes:**
  - `party_role_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `party_id` (FK) - Reference to Party
  - `role_type` - Counterparty, CalculationAgent, etc.
  - `role_description` - Description of the role

### 10. TradeEvent
**Lifecycle Events** - Events that occur during trade lifecycle
- **Attributes:**
  - `event_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `event_type` - Execution, Reset, Termination, etc.
  - `event_date` - Date of the event
  - `effective_date` - When event takes effect
  - `event_qualifier` - CDM event qualifier

### 11. Valuation
**Trade Valuations** - Valuation records for trades
- **Attributes:**
  - `valuation_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `valuation_date` - Date of valuation
  - `valuation_time` - Time of valuation
  - `market_value` - Market value
  - `pv01` - Price Value of 1 basis point
  - `currency` - Valuation currency

### 12. Settlement
**Settlement Instructions** - How trades settle
- **Attributes:**
  - `settlement_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `settlement_date` - When settlement occurs
  - `settlement_amount` - Amount to settle
  - `settlement_currency` - Currency of settlement
  - `settlement_type` - Cash, Physical, etc.

### 13. Collateral
**Collateral Management** - Collateral posted for trades
- **Attributes:**
  - `collateral_id` (PK) - Unique identifier
  - `trade_id` (FK) - Reference to Trade
  - `collateral_type` - Cash, Securities, etc.
  - `collateral_amount` - Amount of collateral
  - `currency` - Collateral currency
  - `posting_date` - When collateral was posted

## Key Relationships

### One-to-Many Relationships

1. **Trade → TradeState**
   - One trade can have many states over time
   - Current state tracked via `is_current` flag

2. **Trade → TradeEvent**
   - One trade can have many lifecycle events
   - Events are chronologically ordered

3. **Trade → Valuation**
   - One trade can have many valuations over time
   - Daily or intraday valuations

4. **TradableProduct → EconomicTerms**
   - One product can have multiple versions of economic terms

5. **EconomicTerms → Payout**
   - One set of economic terms can have multiple payouts (legs)

6. **Party → PartyRole**
   - One party can have multiple roles across different trades

### Many-to-Many Relationships

1. **Trade ↔ Party (via PartyRole)**
   - Many trades can involve many parties
   - Relationship defined through roles

2. **Underlier ↔ PerformancePayout**
   - Basket swaps can reference multiple underliers
   - One underlier can be used in multiple swaps

## Specialized Relationships

### Equity Swap Specific

1. **PerformancePayout → Underlier**
   - Links performance calculation to underlying asset(s)
   - Supports single name, index, and basket configurations

2. **TradeEvent → Settlement**
   - Settlement events trigger settlement instructions
   - Reset events may trigger interim settlements

## Data Integrity Constraints

### Referential Integrity
- All foreign keys must reference valid primary keys
- Cascade delete rules protect data consistency

### Business Rules
1. Trade must have exactly two counterparty roles (Party1, Party2)
2. Performance payout must have valid underlier reference
3. Current trade state must be unique per trade
4. Valuation dates must be business days
5. Settlement dates must follow T+N conventions

## Indexing Strategy

### Primary Indexes
- All primary keys are clustered indexes
- Trade lookup by trade_id is most common

### Secondary Indexes
- `trade_date` for trade reporting
- `party_id` for party position reporting  
- `valuation_date` for risk reporting
- `event_date` for lifecycle event queries

## Audit and Compliance

### Audit Trail
- All entities include creation and update timestamps
- TradeState provides complete state history
- TradeEvent provides complete lifecycle audit

### Regulatory Reporting
- Party LEI codes support regulatory identification
- Trade identifiers support regulatory reporting
- Event qualifiers align with regulatory classifications

## Dynamic Basket Management Extension

### 14. TradeGroup
**Basket Trade Grouping** - Logical grouping of related trades into basket strategies
- **Attributes:**
  - `group_id` (PK) - Unique identifier
  - `group_name` - Human-readable basket name
  - `group_type` - BASKET_STRATEGY, HEDGE_PAIR, SPREAD_TRADE, PORTFOLIO_TRADE
  - `strategy_description` - Detailed strategy description
  - `parent_product_id` (FK) - References logical basket product
  - `group_status` - BUILDING, ACTIVE, PARTIAL_FILLED, COMPLETED, CANCELLED
  - `target_total_notional` - Target total notional amount
  - `target_currency` - Currency of target notional
  - `execution_start_time` - When execution began
  - `execution_end_time` - When execution completed
  - `created_by` - User who created the group
  - `created_timestamp` - Group creation time

### 15. TradeGroupMember
**Basket Components** - Links individual trades to basket groups with weights and roles
- **Attributes:**
  - `group_member_id` (PK) - Unique identifier
  - `group_id` (FK) - Reference to TradeGroup
  - `trade_id` (FK) - Reference to Trade
  - `member_role` - PRIMARY_LEG, HEDGE_LEG, BASKET_COMPONENT, SPREAD_LEG
  - `target_weight` - Expected weight in the basket
  - `actual_weight` - Actual achieved weight
  - `target_notional` - Expected notional amount
  - `actual_notional` - Actual executed notional
  - `execution_sequence` - Order of execution within group
  - `execution_priority` - HIGH, MEDIUM, LOW priority
  - `dependency_member_id` (FK) - Must execute after this member
  - `fill_status` - PENDING, PARTIAL_FILL, FILLED, CANCELLED
  - `created_timestamp` - Member creation time

### 16. BasketCompositionVersion
**Versioned Basket Composition** - Tracks basket composition changes over time
- **Attributes:**
  - `version_id` (PK) - Unique identifier
  - `group_id` (FK) - Reference to TradeGroup
  - `version_number` - Sequential version number
  - `version_date` - Date of version creation
  - `version_type` - INITIAL, ADDITION, REMOVAL, REBALANCE, CORPORATE_ACTION, INDEX_CHANGE
  - `target_composition` (JSON) - New target weights
  - `previous_composition` (JSON) - Previous weights for comparison
  - `composition_changes` (JSON) - Detailed change log
  - `change_reason` - Reason for composition change
  - `change_requested_by` - User who requested change
  - `change_approved_by` - User who approved change
  - `change_approval_date` - When change was approved
  - `effective_date` - When change becomes effective
  - `expected_turnover_pct` - Expected portfolio turnover
  - `estimated_execution_cost` - Estimated cost of rebalancing
  - `estimated_market_impact_bps` - Estimated market impact in basis points
  - `risk_impact_summary` (JSON) - Risk metrics changes
  - `version_status` - PENDING, APPROVED, REJECTED, ACTIVE, SUPERSEDED
  - `created_timestamp` - Version creation time
  - `activated_timestamp` - When version became active

### 17. DynamicUnderlierAddition
**Dynamic Addition Requests** - Tracks requests to add new underliers to existing baskets
- **Attributes:**
  - `addition_id` (PK) - Unique identifier
  - `group_id` (FK) - Reference to TradeGroup
  - `version_id` (FK) - Reference to BasketCompositionVersion
  - `new_underlier_symbol` - Symbol of new underlier to add
  - `new_underlier_name` - Name of new underlier
  - `new_underlier_sector` - Sector classification
  - `new_underlier_country` - Country of domicile
  - `target_weight` - Target weight in basket
  - `target_notional` - Target notional amount
  - `addition_source` - INDEX_ADDITION, STRATEGIC_DECISION, OPPORTUNISTIC, RISK_MANAGEMENT, CORPORATE_ACTION, CLIENT_REQUEST, REGULATORY_REQUIREMENT
  - `addition_rationale` - Detailed rationale for addition
  - `expected_benefit` (JSON) - Expected impact metrics
  - `execution_priority` - HIGH, MEDIUM, LOW priority
  - `execution_timeline` - Target execution timeframe
  - `execution_constraints` (JSON) - Special execution requirements
  - `weight_rebalance_method` - PRO_RATA_REDUCTION, TARGETED_REDUCTION, CASH_INJECTION, SECTOR_NEUTRAL
  - `affected_positions` (JSON) - Positions affected by rebalancing
  - `rebalance_trades_required` - Number of trades needed for rebalancing
  - `addition_status` - REQUESTED, UNDER_REVIEW, APPROVED, REJECTED, EXECUTING, COMPLETED, FAILED
  - `requested_by` - User who requested addition
  - `requested_date` - Date of request
  - `reviewed_by` - User who reviewed request
  - `review_date` - Date of review
  - `review_notes` - Review comments

### 18. RebalancingWorkflow
**Rebalancing Execution Management** - Manages the execution of rebalancing workflows
- **Attributes:**
  - `workflow_id` (PK) - Unique identifier
  - `group_id` (FK) - Reference to TradeGroup
  - `version_id` (FK) - Reference to BasketCompositionVersion
  - `workflow_type` - ADDITION_REBALANCE, REMOVAL_REBALANCE, WEIGHT_ADJUSTMENT, FULL_RECONSTITUTION
  - `total_trades_required` - Total number of trades needed
  - `completed_trades` - Number of completed trades
  - `failed_trades` - Number of failed trades
  - `estimated_execution_time` - Estimated completion time
  - `actual_start_time` - When execution actually started
  - `actual_end_time` - When execution actually completed
  - `execution_strategy` - SIMULTANEOUS, SEQUENTIAL, BATCH_EXECUTION, TWAP, VWAP, IMPLEMENTATION_SHORTFALL
  - `max_market_impact_bps` - Maximum allowed market impact
  - `execution_urgency` - LOW, NORMAL, HIGH, URGENT
  - `completion_percentage` - Current completion percentage
  - `current_tracking_error` - Current tracking error vs target
  - `current_cash_balance` - Current cash balance from rebalancing
  - `risk_limit_breaches` - Number of risk limit breaches
  - `max_position_deviation_pct` - Maximum allowed position deviation
  - `intraday_risk_monitoring` - Enable/disable intraday risk monitoring
  - `workflow_status` - PLANNED, APPROVED, EXECUTING, PAUSED, COMPLETED, FAILED, CANCELLED
  - `created_by` - User who created workflow
  - `created_timestamp` - Workflow creation time

### 19. RebalancingTrade
**Individual Rebalancing Trades** - Individual trades within rebalancing workflows
- **Attributes:**
  - `rebalancing_trade_id` (PK) - Unique identifier
  - `workflow_id` (FK) - Reference to RebalancingWorkflow
  - `trade_id` (FK) - Reference to actual Trade when executed
  - `underlier_symbol` - Symbol of the underlier being traded
  - `trade_type` - NEW_ADDITION, WEIGHT_INCREASE, WEIGHT_DECREASE, FULL_LIQUIDATION
  - `side` - BUY or SELL
  - `target_quantity` - Target quantity to trade
  - `target_notional` - Target notional amount
  - `target_weight_change` - Change in basket weight
  - `execution_sequence` - Order of execution within workflow
  - `current_weight` - Current weight before trade
  - `target_weight` - Target weight after trade
  - `weight_adjustment` - Net weight adjustment
  - `execution_status` - PENDING, STAGED, SUBMITTED, PARTIAL_FILL, FILLED, CANCELLED, FAILED
  - `execution_timestamp` - When trade was executed
  - `filled_quantity` - Actually filled quantity
  - `average_fill_price` - Average execution price
  - `execution_venue` - Where trade was executed
  - `dependency_trade_id` (FK) - Must complete before this trade
  - `execution_constraint` (JSON) - Special constraints
  - `created_timestamp` - Trade creation time

### 20. BasketCompositionHistory
**Composition Change Audit Trail** - Complete audit trail of all basket changes
- **Attributes:**
  - `history_id` (PK) - Unique identifier
  - `group_id` (FK) - Reference to TradeGroup
  - `change_date` - Date of composition change
  - `change_type` - Type of change made
  - `composition_before` (JSON) - Composition before change
  - `composition_after` (JSON) - Composition after change
  - `change_details` (JSON) - Detailed change breakdown
  - `turnover_generated` - Actual turnover percentage
  - `execution_cost_incurred` - Actual execution cost
  - `tracking_error_impact` - Impact on tracking error
  - `initiated_by` - User who initiated change
  - `approved_by` - User who approved change
  - `executed_by` - User who executed change
  - `change_reason` - Reason for change
  - `created_timestamp` - History record creation time

## Extended Relationships

### Dynamic Basket Management Relationships

1. **TradeGroup → TradeGroupMember**
   - One basket group can have many component trades
   - Supports complex basket strategies with multiple legs

2. **TradeGroup → BasketCompositionVersion**
   - One basket can have many composition versions over time
   - Supports versioned composition management

3. **BasketCompositionVersion → DynamicUnderlierAddition**
   - One version can have multiple dynamic addition requests
   - Supports batch changes and multiple simultaneous requests

4. **BasketCompositionVersion → RebalancingWorkflow**
   - One version change can trigger one or more rebalancing workflows
   - Supports complex execution strategies

5. **RebalancingWorkflow → RebalancingTrade**
   - One workflow can contain many individual trades
   - Supports dependency-based execution sequencing

6. **TradeGroup → BasketCompositionHistory**
   - One basket maintains complete history of all changes
   - Provides full audit trail for regulatory compliance

7. **RebalancingTrade → Trade**
   - Links rebalancing trades to actual executed trades
   - Maintains connection between planning and execution

### Complex Dependencies

1. **TradeGroupMember Self-Reference**
   - Members can depend on other members for execution order
   - Supports complex basket construction sequences

2. **RebalancingTrade Self-Reference**
   - Trades can depend on other trades within workflow
   - Ensures proper execution sequencing and risk management

## Business Rules - Dynamic Basket Extension

### Composition Management
1. Only one BasketCompositionVersion can be ACTIVE per TradeGroup at a time
2. Version numbers must be sequential within each TradeGroup
3. Target weights in composition must sum to 100% (or close within tolerance)
4. Effective dates cannot overlap for the same TradeGroup

### Dynamic Addition Rules
1. DynamicUnderlierAddition can only be APPROVED if associated version is APPROVED
2. Target weight must be positive and less than maximum concentration limit
3. Addition must not violate overall basket constraints (sector limits, country limits, etc.)
4. Rebalancing method must be appropriate for the basket strategy type

### Rebalancing Workflow Rules
1. RebalancingWorkflow can only be EXECUTING if all prerequisite approvals are in place
2. Total trades required must match sum of individual RebalancingTrade records
3. Market impact limits must not be exceeded during execution
4. Risk limit breaches must halt execution if configured

### Execution Sequencing
1. RebalancingTrades with dependencies must wait for dependency completion
2. Execution sequence must be unique within each workflow
3. Failed trades must be handled according to configured failure policies
4. Partial fills must be tracked and managed for completion

## Indexing Strategy - Extended

### Dynamic Basket Indexes
- `group_id + version_number` for composition lookups
- `addition_status + requested_date` for pending request monitoring
- `workflow_status + created_timestamp` for active workflow tracking
- `execution_sequence + workflow_id` for trade ordering
- `change_date + group_id` for historical analysis

### Performance Optimization
- Composite indexes on frequently queried combinations
- Partial indexes on active/pending status records only
- JSON indexes on composition and change detail fields
- Covering indexes for dashboard and reporting queries

This ER model provides a comprehensive foundation for equity swap management while maintaining alignment with CDM standards and regulatory requirements. The dynamic basket management extension enables real-time portfolio optimization, complex execution workflows, and comprehensive audit trails for institutional trading operations.
