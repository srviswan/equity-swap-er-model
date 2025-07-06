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

This ER model provides a comprehensive foundation for equity swap management while maintaining alignment with CDM standards and regulatory requirements.
