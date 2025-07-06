# Entity Relationships

## Overview

This document defines all relationships between entities in the equity swap management system, including cardinality, referential integrity rules, and business constraints.

## Core Trade Relationships

### Trade ↔ TradeState (1:M)
**Relationship:** One trade can have many states throughout its lifecycle
- **Foreign Key:** `TradeState.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many states)
- **Business Rules:**
  - Every trade must have at least one state (initial execution state)
  - Only one state can be marked as current (`is_current = TRUE`)
  - States must be chronologically ordered
  - State transitions must follow defined lifecycle rules

**SQL Constraint:**
```sql
CONSTRAINT fk_tradestate_trade 
    FOREIGN KEY (trade_id) REFERENCES Trade(trade_id) 
    ON DELETE CASCADE ON UPDATE CASCADE
```

### Trade ↔ TradableProduct (M:1)
**Relationship:** Many trades can reference the same tradable product
- **Foreign Key:** `Trade.product_id` → `TradableProduct.product_id`
- **Cardinality:** M:1 (Many trades to one product)
- **Business Rules:**
  - Product must be active when trade is created
  - Product type determines valid payout structures

### TradableProduct ↔ EconomicTerms (1:M)
**Relationship:** One product can have multiple versions of economic terms
- **Foreign Key:** `EconomicTerms.product_id` → `TradableProduct.product_id`
- **Cardinality:** 1:M (One product to many economic terms versions)
- **Business Rules:**
  - Each version must have unique effective dates
  - Terms cannot overlap in time for same product
  - Only one version can be active at any time

## Payout Structure Relationships

### EconomicTerms ↔ Payout (1:M)
**Relationship:** One set of economic terms can have multiple payouts (legs)
- **Foreign Key:** `Payout.economic_terms_id` → `EconomicTerms.economic_terms_id`
- **Cardinality:** 1:M (One economic terms to many payouts)
- **Business Rules:**
  - Equity swap must have at least one performance payout
  - Can have multiple payouts for different legs (performance + interest rate)
  - Payer and receiver parties must be different

### Payout ↔ PerformancePayout (1:1)
**Relationship:** One-to-one extension for performance-specific attributes
- **Foreign Key:** `PerformancePayout.payout_id` → `Payout.payout_id`
- **Cardinality:** 1:1 (One payout to one performance payout)
- **Business Rules:**
  - Only payouts with type 'PERFORMANCE' can have performance payout
  - Performance payout inherits all base payout attributes

## Asset and Reference Data Relationships

### PerformancePayout ↔ Underlier (M:M)
**Relationship:** Many-to-many through PerformancePayoutUnderlier junction table
- **Junction Table:** `PerformancePayoutUnderlier`
- **Foreign Keys:** 
  - `performance_payout_id` → `PerformancePayout.performance_payout_id`
  - `underlier_id` → `Underlier.underlier_id`
- **Cardinality:** M:M (Many performance payouts to many underliers)
- **Business Rules:**
  - Single name swaps: exactly one underlier
  - Basket swaps: multiple underliers with weights
  - Index swaps: one index underlier

**Junction Table Attributes:**
```sql
CREATE TABLE PerformancePayoutUnderlier (
    performance_payout_id VARCHAR(50) NOT NULL,
    underlier_id VARCHAR(50) NOT NULL,
    weight DECIMAL(10,6) DEFAULT 1.0,
    effective_date DATE NOT NULL,
    termination_date DATE,
    PRIMARY KEY (performance_payout_id, underlier_id, effective_date)
);
```

### Underlier ↔ BasketComponent (1:M)
**Relationship:** One basket underlier contains many component underliers
- **Foreign Key:** `BasketComponent.basket_id` → `Underlier.underlier_id`
- **Foreign Key:** `BasketComponent.component_underlier_id` → `Underlier.underlier_id`
- **Cardinality:** 1:M (One basket to many components)
- **Business Rules:**
  - Only underliers with `asset_type = 'BASKET'` can be baskets
  - Component weights must sum to 1.0 on any effective date
  - Components cannot reference themselves (no circular references)

## Party and Role Relationships

### Trade ↔ Party (M:M via PartyRole)
**Relationship:** Many-to-many through PartyRole junction table
- **Junction Table:** `PartyRole`
- **Foreign Keys:**
  - `trade_id` → `Trade.trade_id`
  - `party_id` → `Party.party_id`
- **Cardinality:** M:M (Many trades to many parties)
- **Business Rules:**
  - Each trade must have exactly 2 counterparty roles
  - Same party can have multiple roles in same trade (if not conflicting)
  - Each role must have unique effective date ranges

### Payout ↔ Party (M:1 for Payer and Receiver)
**Relationship:** Each payout has one payer and one receiver
- **Foreign Keys:**
  - `Payout.payer_party_id` → `Party.party_id`
  - `Payout.receiver_party_id` → `Party.party_id`
- **Cardinality:** M:1 (Many payouts to one party for each role)
- **Business Rules:**
  - Payer and receiver must be different parties
  - Both parties must be counterparties in the trade

## Event and Lifecycle Relationships

### Trade ↔ TradeEvent (1:M)
**Relationship:** One trade can have many lifecycle events
- **Foreign Key:** `TradeEvent.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many events)
- **Business Rules:**
  - First event must be 'EXECUTION'
  - Events must be chronologically ordered
  - Certain events require specific prerequisites

### Trade ↔ ObservationEvent (1:M)
**Relationship:** One trade can have many observation events
- **Foreign Key:** `ObservationEvent.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many observations)
- **Business Rules:**
  - Observations must be for underliers referenced in trade
  - Observation dates must be within trade effective period

### ObservationEvent ↔ Underlier (M:1)
**Relationship:** Many observations can reference one underlier
- **Foreign Key:** `ObservationEvent.underlier_id` → `Underlier.underlier_id`
- **Cardinality:** M:1 (Many observations to one underlier)

## Valuation and Risk Relationships

### Trade ↔ Valuation (1:M)
**Relationship:** One trade can have many valuations over time
- **Foreign Key:** `Valuation.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many valuations)
- **Business Rules:**
  - Valuations must be dated within trade lifecycle
  - Multiple valuations per day allowed (intraday)
  - Latest valuation represents current market value

## Settlement and Collateral Relationships

### Trade ↔ Settlement (1:M)
**Relationship:** One trade can have many settlement instructions
- **Foreign Key:** `Settlement.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many settlements)
- **Business Rules:**
  - Settlement parties must be trade counterparties
  - Settlement dates must align with payment schedule

### Settlement ↔ Party (M:1 for Payer and Receiver)
**Relationship:** Each settlement has one payer and one receiver
- **Foreign Keys:**
  - `Settlement.payer_party_id` → `Party.party_id`
  - `Settlement.receiver_party_id` → `Party.party_id`
- **Cardinality:** M:1 (Many settlements to one party for each role)

### Trade ↔ Collateral (1:M)
**Relationship:** One trade can have multiple collateral postings
- **Foreign Key:** `Collateral.trade_id` → `Trade.trade_id`
- **Cardinality:** 1:M (One trade to many collateral postings)
- **Business Rules:**
  - Collateral parties must be trade counterparties
  - Total collateral value must meet margin requirements

### Collateral ↔ Party (M:1 for Posting and Receiving)
**Relationship:** Each collateral posting has one posting party and one receiving party
- **Foreign Keys:**
  - `Collateral.posting_party_id` → `Party.party_id`
  - `Collateral.receiving_party_id` → `Party.party_id`
- **Cardinality:** M:1 (Many collateral postings to one party for each role)

## Specialized Equity Swap Relationships

### Price Return vs Total Return Relationships
**Price Return Swaps:**
- Must have `PerformancePayout.return_type = 'PRICE_RETURN'`
- No dividend return terms required
- Focus on price appreciation/depreciation

**Total Return Swaps:**
- Must have `PerformancePayout.return_type = 'TOTAL_RETURN'`
- Requires dividend observation events
- Includes both price and dividend returns

### Variance/Volatility Swap Relationships
**Variance Swaps:**
- `PerformancePayout.return_type = 'VARIANCE_RETURN'`
- Requires daily price observations
- Settlement based on realized variance

**Volatility Swaps:**
- `PerformancePayout.return_type = 'VOLATILITY_RETURN'`
- Requires daily price observations  
- Settlement based on realized volatility

## Cross-Reference Relationships

### Master Agreement References
Many trades can reference the same master agreement:
- **Field:** `Trade.master_agreement_id`
- **Relationship:** Logical reference (not foreign key)
- **Business Rule:** Master agreement governs trade terms

### Regulatory Reporting Relationships
- **LEI Codes:** `Party.lei_code` for regulatory identification
- **UTI/USI:** `Trade.trade_id` for regulatory reporting
- **Event Qualifiers:** `TradeEvent.event_qualifier` for lifecycle reporting

## Referential Integrity Rules

### Cascade Delete Rules
1. **Trade deletion:** Cascades to TradeState, TradeEvent, Valuation, Settlement, Collateral
2. **Party deletion:** Restricted if referenced in active trades
3. **Underlier deletion:** Restricted if referenced in active trades
4. **Product deletion:** Restricted if referenced in active trades

### Update Cascade Rules
1. **Trade ID changes:** Cascade to all dependent tables
2. **Party ID changes:** Cascade to all dependent tables
3. **Product ID changes:** Cascade to all dependent tables

### Check Constraints
1. **Date Consistency:** Effective dates ≤ Termination dates
2. **Amount Positivity:** Notional amounts, prices > 0
3. **Currency Validity:** All currency codes must be valid ISO 4217
4. **Percentage Ranges:** Weights, haircuts between 0-100%

## Business Rule Enforcement

### Trade Lifecycle Rules
1. Trade must start with EXECUTION event
2. TERMINATION events end the trade lifecycle
3. State transitions must follow defined paths
4. Events must be chronologically ordered

### Financial Rules
1. Notional amounts must be positive
2. Basket weights must sum to 1.0
3. Collateral value ≥ margin requirements
4. Settlement amounts must balance

### Regulatory Rules
1. All parties must have valid LEI codes
2. Trades must have unique UTI/USI identifiers
3. Event qualifiers must match regulatory taxonomy
4. Reporting deadlines must be met

This relationship structure ensures data integrity, supports complex equity swap structures, and maintains compliance with regulatory requirements while providing the flexibility needed for modern equity swap management.
