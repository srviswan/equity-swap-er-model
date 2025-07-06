# Entity Definitions

## Core Trading Entities

### Trade
Represents a completed equity swap transaction between counterparties.

**Attributes:**
- `trade_id` VARCHAR(50) PRIMARY KEY - Unique trade identifier (UTI/USI)
- `trade_date` DATE NOT NULL - Date when trade was agreed
- `trade_time` TIMESTAMP - Exact time of trade execution with timezone
- `status` ENUM('ACTIVE', 'TERMINATED', 'SUSPENDED') - Current trade status
- `master_agreement_id` VARCHAR(50) - Reference to master agreement
- `confirmation_method` ENUM('ELECTRONIC', 'MANUAL') - How trade was confirmed
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
- `updated_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

**Business Rules:**
- Trade date cannot be in the future
- Status transitions must follow defined lifecycle
- UTI/USI must be globally unique

### TradeState
Maintains the current and historical states of a trade throughout its lifecycle.

**Attributes:**
- `trade_state_id` VARCHAR(50) PRIMARY KEY - Unique state identifier
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `state_timestamp` TIMESTAMP NOT NULL - When this state became effective
- `state_type` ENUM('EXECUTION', 'RESET', 'PARTIAL_TERMINATION', 'FULL_TERMINATION', 'AMENDMENT') - Type of state change
- `is_current` BOOLEAN DEFAULT FALSE - Indicates current state
- `previous_state_id` VARCHAR(50) - Reference to previous state (for audit trail)
- `created_by` VARCHAR(100) - User or system that created this state

**Business Rules:**
- Only one current state per trade
- State timestamp must be chronological
- Previous state reference maintains audit chain

### TradableProduct
Defines the equity swap product structure and characteristics.

**Attributes:**
- `product_id` VARCHAR(50) PRIMARY KEY - Unique product identifier
- `product_type` ENUM('EQUITY_SWAP_PRICE_RETURN', 'EQUITY_SWAP_TOTAL_RETURN', 'EQUITY_SWAP_VARIANCE', 'EQUITY_SWAP_VOLATILITY') - Specific equity swap type
- `product_name` VARCHAR(200) - Human-readable product name
- `asset_class` VARCHAR(50) DEFAULT 'EQUITY' - Asset class classification
- `sub_asset_class` VARCHAR(50) DEFAULT 'SWAP' - Sub-asset class
- `version` INTEGER DEFAULT 1 - Product version for changes
- `is_active` BOOLEAN DEFAULT TRUE - Whether product can be traded
- `created_date` DATE NOT NULL
- `created_by` VARCHAR(100)

### EconomicTerms
Contains the detailed economic and contractual terms of the equity swap.

**Attributes:**
- `economic_terms_id` VARCHAR(50) PRIMARY KEY
- `product_id` VARCHAR(50) NOT NULL - Foreign key to TradableProduct
- `effective_date` DATE NOT NULL - When terms become effective
- `termination_date` DATE - When terms expire (NULL for open-ended)
- `calculation_agent_id` VARCHAR(50) - Foreign key to Party (calculation agent)
- `business_day_convention` ENUM('FOLLOWING', 'MODIFIED_FOLLOWING', 'PRECEDING', 'MODIFIED_PRECEDING') - Date adjustment rule
- `business_centers` JSON - Array of business center codes for holidays
- `extraordinary_events` JSON - Extraordinary events provisions
- `version` INTEGER DEFAULT 1

**Business Rules:**
- Effective date ≤ Termination date
- Business centers must be valid ISO country/city codes
- Calculation agent must be a valid party

## Payout Structure

### Payout
Base payout structure for all types of payments in the swap.

**Attributes:**
- `payout_id` VARCHAR(50) PRIMARY KEY
- `economic_terms_id` VARCHAR(50) NOT NULL - Foreign key to EconomicTerms
- `payout_type` ENUM('PERFORMANCE', 'INTEREST_RATE', 'FIXED') - Type of payout calculation
- `payer_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who pays)
- `receiver_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who receives)
- `payment_frequency` ENUM('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'SEMI_ANNUALLY', 'ANNUALLY', 'AT_MATURITY') - How often payments occur
- `day_count_fraction` ENUM('30/360', 'ACT/360', 'ACT/365', 'ACT/ACT') - Day count calculation method
- `currency` CHAR(3) NOT NULL - ISO currency code

### PerformancePayout
Specialized payout for equity performance calculations (extends Payout concept).

**Attributes:**
- `performance_payout_id` VARCHAR(50) PRIMARY KEY
- `payout_id` VARCHAR(50) NOT NULL - Foreign key to base Payout
- `return_type` ENUM('PRICE_RETURN', 'TOTAL_RETURN', 'VARIANCE_RETURN', 'VOLATILITY_RETURN') - Type of return calculation
- `initial_price` DECIMAL(18,6) - Starting price for performance calculation
- `initial_price_date` DATE - Date of initial price
- `notional_amount` DECIMAL(18,2) NOT NULL - Notional amount for calculation
- `notional_currency` CHAR(3) NOT NULL - Currency of notional
- `number_of_data_series` INTEGER DEFAULT 1 - For basket calculations
- `observation_start_date` DATE - Start of observation period
- `observation_end_date` DATE - End of observation period
- `valuation_time` TIME - Time of day for observations
- `market_disruption_events` JSON - Market disruption provisions

**Business Rules:**
- Initial price must be > 0
- Notional amount must be > 0
- Observation dates must be within trade effective/termination dates
- Return type must be consistent with product type

## Asset and Reference Data

### Underlier
Represents the underlying assets (stocks, indices, baskets) for equity swaps.

**Attributes:**
- `underlier_id` VARCHAR(50) PRIMARY KEY
- `asset_type` ENUM('SINGLE_NAME', 'INDEX', 'BASKET') - Type of underlying
- `primary_identifier` VARCHAR(50) NOT NULL - Main identifier (ISIN, RIC, etc.)
- `identifier_type` ENUM('ISIN', 'CUSIP', 'RIC', 'BLOOMBERG', 'INTERNAL') - Type of identifier
- `secondary_identifiers` JSON - Additional identifiers as key-value pairs
- `asset_name` VARCHAR(200) NOT NULL - Full name of the asset
- `asset_description` TEXT - Detailed description
- `currency` CHAR(3) NOT NULL - Primary trading currency
- `exchange` VARCHAR(50) - Primary trading exchange
- `country` CHAR(2) - ISO country code
- `sector` VARCHAR(100) - Industry sector
- `is_active` BOOLEAN DEFAULT TRUE - Whether asset is still active
- `created_date` DATE NOT NULL
- `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

### BasketComponent
For basket underliers, defines the individual components and their weights.

**Attributes:**
- `component_id` VARCHAR(50) PRIMARY KEY
- `basket_id` VARCHAR(50) NOT NULL - Foreign key to Underlier (basket)
- `component_underlier_id` VARCHAR(50) NOT NULL - Foreign key to Underlier (component)
- `weight` DECIMAL(10,6) NOT NULL - Weight in the basket (0-1)
- `shares` DECIMAL(18,6) - Number of shares if quantity-based
- `effective_date` DATE NOT NULL - When this weighting became effective
- `termination_date` DATE - When this weighting ends

**Business Rules:**
- Weights in a basket must sum to 1.0 on any given date
- Component cannot reference itself
- Effective date must be ≤ current date

## Party and Role Management

### Party
Represents all legal entities involved in equity swap transactions.

**Attributes:**
- `party_id` VARCHAR(50) PRIMARY KEY
- `party_name` VARCHAR(200) NOT NULL - Legal name
- `party_type` ENUM('BANK', 'FUND', 'CORPORATION', 'INDIVIDUAL', 'GOVERNMENT', 'OTHER') - Type of entity
- `lei_code` CHAR(20) - Legal Entity Identifier
- `party_identifiers` JSON - Additional identifiers (internal IDs, swift codes, etc.)
- `country_of_incorporation` CHAR(2) - ISO country code
- `address` JSON - Structured address information
- `contact_information` JSON - Phone, email, etc.
- `regulatory_status` JSON - Regulatory classifications
- `credit_rating` VARCHAR(10) - External credit rating
- `is_active` BOOLEAN DEFAULT TRUE
- `created_date` DATE NOT NULL
- `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

### PartyRole
Defines the specific roles parties play in each trade.

**Attributes:**
- `party_role_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `party_id` VARCHAR(50) NOT NULL - Foreign key to Party
- `role_type` ENUM('COUNTERPARTY_1', 'COUNTERPARTY_2', 'CALCULATION_AGENT', 'PAYING_AGENT', 'DETERMINING_PARTY', 'BROKER') - Specific role
- `role_description` TEXT - Additional role details
- `effective_date` DATE NOT NULL - When role assignment starts
- `termination_date` DATE - When role assignment ends
- `created_by` VARCHAR(100)
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP

**Business Rules:**
- Each trade must have exactly 2 counterparty roles
- Same party cannot have conflicting roles in same trade
- Role effective dates must be within trade lifecycle

## Event and Lifecycle Management

### TradeEvent
Captures all significant events during the trade lifecycle.

**Attributes:**
- `event_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `event_type` ENUM('EXECUTION', 'CONFIRMATION', 'RESET', 'PAYMENT', 'CORPORATE_ACTION', 'AMENDMENT', 'PARTIAL_TERMINATION', 'FULL_TERMINATION', 'DEFAULT', 'EXTRAORDINARY_EVENT') - Type of event
- `event_date` DATE NOT NULL - Date when event occurred
- `effective_date` DATE - Date when event takes effect (if different)
- `event_qualifier` VARCHAR(100) - CDM event qualifier for regulatory reporting
- `event_details` JSON - Structured event-specific data
- `triggered_by` VARCHAR(100) - What caused this event
- `processed_by` VARCHAR(100) - System/user that processed event
- `processing_status` ENUM('PENDING', 'PROCESSED', 'FAILED', 'CANCELLED') - Current status
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP

### ObservationEvent
Specific events related to underlying asset observations.

**Attributes:**
- `observation_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `observation_date` DATE NOT NULL - Date of observation
- `observation_time` TIME - Time of observation
- `underlier_id` VARCHAR(50) NOT NULL - Foreign key to Underlier
- `observed_price` DECIMAL(18,6) NOT NULL - Observed price/value
- `observation_type` ENUM('CLOSING_PRICE', 'OPENING_PRICE', 'INTRADAY_PRICE', 'VOLUME', 'DIVIDEND') - What was observed
- `source` VARCHAR(100) - Data source
- `market_disruption` BOOLEAN DEFAULT FALSE - Whether market disruption occurred
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP

## Valuation and Risk

### Valuation
Stores trade valuations for risk management and reporting.

**Attributes:**
- `valuation_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `valuation_date` DATE NOT NULL - Date of valuation
- `valuation_time` TIMESTAMP - Exact time of valuation
- `valuation_type` ENUM('MARK_TO_MARKET', 'MARK_TO_MODEL', 'THIRD_PARTY') - Valuation method
- `base_currency` CHAR(3) NOT NULL - Base currency for reporting
- `market_value` DECIMAL(18,2) NOT NULL - Current market value
- `unrealized_pnl` DECIMAL(18,2) - Unrealized P&L since inception
- `daily_pnl` DECIMAL(18,2) - Daily P&L change
- `pv01` DECIMAL(18,6) - Price value of 1 basis point
- `delta` DECIMAL(18,6) - Price sensitivity to underlying
- `gamma` DECIMAL(18,6) - Delta sensitivity to underlying
- `vega` DECIMAL(18,6) - Sensitivity to volatility
- `theta` DECIMAL(18,6) - Time decay
- `model_inputs` JSON - Model parameters used
- `created_by` VARCHAR(100)
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP

## Settlement and Collateral

### Settlement
Settlement instructions and records for equity swap payments.

**Attributes:**
- `settlement_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `settlement_date` DATE NOT NULL - When settlement occurs
- `settlement_type` ENUM('CASH', 'PHYSICAL', 'NET_CASH') - Type of settlement
- `settlement_amount` DECIMAL(18,2) NOT NULL - Amount to settle
- `settlement_currency` CHAR(3) NOT NULL - Currency of settlement
- `payer_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who pays)
- `receiver_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who receives)
- `payment_method` ENUM('WIRE', 'ACH', 'BOOK_TRANSFER') - How payment is made
- `settlement_status` ENUM('PENDING', 'SETTLED', 'FAILED', 'CANCELLED') - Current status
- `settlement_reference` VARCHAR(100) - External settlement reference
- `failure_reason` TEXT - Reason for settlement failure
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
- `settled_timestamp` TIMESTAMP - When actually settled

### Collateral
Collateral management for equity swap trades.

**Attributes:**
- `collateral_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Foreign key to Trade
- `collateral_type` ENUM('CASH', 'GOVERNMENT_BONDS', 'CORPORATE_BONDS', 'EQUITIES', 'OTHER_SECURITIES') - Type of collateral
- `collateral_amount` DECIMAL(18,2) NOT NULL - Amount of collateral
- `collateral_currency` CHAR(3) NOT NULL - Currency of collateral
- `posting_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who posts)
- `receiving_party_id` VARCHAR(50) NOT NULL - Foreign key to Party (who receives)
- `posting_date` DATE NOT NULL - Date collateral was posted
- `maturity_date` DATE - When collateral matures/returns
- `haircut_percentage` DECIMAL(5,2) - Haircut applied (0-99.99%)
- `collateral_value` DECIMAL(18,2) - Market value after haircut
- `status` ENUM('POSTED', 'RETURNED', 'SUBSTITUTED') - Current status
- `custodian` VARCHAR(100) - Collateral custodian
- `created_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP

## Data Quality and Audit

### DataQualityRule
Defines data quality validation rules for the system.

**Attributes:**
- `rule_id` VARCHAR(50) PRIMARY KEY
- `rule_name` VARCHAR(200) NOT NULL - Descriptive name
- `entity_name` VARCHAR(100) NOT NULL - Which entity the rule applies to
- `rule_type` ENUM('REQUIRED_FIELD', 'FORMAT_VALIDATION', 'BUSINESS_RULE', 'CROSS_REFERENCE') - Type of validation
- `rule_expression` TEXT NOT NULL - SQL or other expression defining the rule
- `error_message` TEXT NOT NULL - Message when rule fails
- `severity` ENUM('ERROR', 'WARNING', 'INFO') - Severity of rule violation
- `is_active` BOOLEAN DEFAULT TRUE
- `created_date` DATE NOT NULL

### AuditLog
Comprehensive audit trail for all system changes.

**Attributes:**
- `audit_id` VARCHAR(50) PRIMARY KEY
- `table_name` VARCHAR(100) NOT NULL - Which table was changed
- `record_id` VARCHAR(50) NOT NULL - ID of the changed record
- `operation_type` ENUM('INSERT', 'UPDATE', 'DELETE') - Type of operation
- `old_values` JSON - Previous values (for updates/deletes)
- `new_values` JSON - New values (for inserts/updates)
- `changed_by` VARCHAR(100) NOT NULL - User or system making change
- `change_reason` TEXT - Reason for the change
- `change_timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
- `session_id` VARCHAR(100) - Session identifier
- `ip_address` VARCHAR(45) - IP address of the change source

This comprehensive entity definition provides a robust foundation for equity swap management while ensuring data quality, audit trails, and regulatory compliance.
