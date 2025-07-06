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

### FXRate
Manages foreign exchange rates for cross-currency equity swaps.

**Attributes:**
- `fx_rate_id` VARCHAR(50) PRIMARY KEY
- `base_currency` CHAR(3) NOT NULL - Base currency (3-letter ISO code)
- `quote_currency` CHAR(3) NOT NULL - Quote currency (3-letter ISO code)
- `rate_date` DATE NOT NULL - Date of the rate
- `rate_time` TIME - Time of the rate (optional)
- `rate_value` DECIMAL(18,6) NOT NULL - Exchange rate value
- `rate_source` VARCHAR(100) NOT NULL - Source of the rate (e.g., 'WM/Reuters')
- `rate_type` ENUM('SPOT', 'FORWARD', 'IMPLIED', 'FIXING') - Type of rate
- `forward_date` DATE - Forward date for forward rates
- `is_active` BOOLEAN DEFAULT TRUE - Whether the rate is active

**Business Rules:**
- Unique combination of base/quote currency, date, and time
- Base and quote currencies must be different
- Rate value must be positive
- Support for both spot and forward rates
- Historical rate preservation for audit trails

### CurrencyPair
Defines currency pair configurations and market conventions.

**Attributes:**
- `currency_pair_id` VARCHAR(50) PRIMARY KEY
- `base_currency` CHAR(3) NOT NULL - Base currency (3-letter ISO code)
- `quote_currency` CHAR(3) NOT NULL - Quote currency (3-letter ISO code)
- `pair_code` VARCHAR(6) NOT NULL - Standard 6-character pair code (e.g., 'EURUSD')
- `market_convention` TEXT NOT NULL - Market convention description
- `spot_days` INTEGER NOT NULL - Standard settlement days for spot transactions
- `tick_size` DECIMAL(18,6) NOT NULL - Minimum price movement
- `is_active` BOOLEAN DEFAULT TRUE - Whether the pair is actively traded

**Business Rules:**
- Unique combination of base and quote currencies
- Pair code must be unique across all pairs
- Base and quote currencies must be different
- Market convention defines fixing times and sources
- Tick size defines precision for rate quotations

### FXResetEvent
Tracks FX rate reset/fixing events for cross-currency payouts.

**Attributes:**
- `fx_reset_id` VARCHAR(50) PRIMARY KEY
- `trade_id` VARCHAR(50) NOT NULL - Associated trade identifier
- `payout_id` VARCHAR(50) NOT NULL - Associated payout identifier
- `reset_date` DATE NOT NULL - Date of the FX reset
- `reset_time` TIME NOT NULL - Time of the FX reset
- `base_currency` CHAR(3) NOT NULL - Base currency for the reset
- `quote_currency` CHAR(3) NOT NULL - Quote currency for the reset
- `fx_rate` DECIMAL(18,6) NOT NULL - Fixed exchange rate
- `fx_rate_source` VARCHAR(100) NOT NULL - Source of the FX rate
- `reset_type` ENUM('INITIAL', 'PERIODIC', 'FINAL', 'BARRIER') - Type of reset
- `reset_status` ENUM('PENDING', 'FIXED', 'FAILED') - Status of the reset
- `payment_date` DATE NOT NULL - Associated payment date

**Business Rules:**
- Links to specific trade and payout
- Base and quote currencies must be different
- Reset type determines the purpose of the fixing
- Status tracks the lifecycle of the reset event
- Payment date determines when the fixed rate is applied
- Supports multiple reset types for different scenarios

### WorkflowDefinition

Defines reusable workflow templates for automated business processes.

**Primary Key**: `workflow_definition_id`

**Key Attributes**:
- `workflow_name` - Human-readable workflow name
- `workflow_type` - Type (TRADE_BOOKING, SETTLEMENT_PROCESS, VALUATION_PROCESS, etc.)
- `workflow_version` - Version for template management
- `description` - Detailed workflow description
- `is_active` - Whether workflow is currently active
- `auto_start` - Whether workflow starts automatically
- `timeout_hours` - Maximum execution time allowed
- `created_by` / `modified_by` - Audit trail

**Business Rules:**
- Only active workflows can be instantiated
- Version management allows workflow evolution
- Timeout enforces SLA compliance
- Auto-start enables lights-out processing
- Supports multiple concurrent versions

### WorkflowInstance

Tracks individual executions of workflow definitions.

**Primary Key**: `workflow_instance_id`

**Key Attributes**:
- `workflow_definition_id` - Template reference
- `entity_type` / `entity_id` - Associated business entity
- `instance_status` - Current status (PENDING, RUNNING, COMPLETED, FAILED, CANCELLED)
- `priority_level` - Processing priority (1=highest, 5=lowest)
- `started_date` / `completed_date` - Execution timeline
- `timeout_date` - When instance will timeout
- `error_message` - Failure details if applicable

**Business Rules:**
- Each instance tied to specific business entity
- Status transitions follow predefined lifecycle
- Priority affects processing order
- Timeout management prevents hung processes
- Error tracking for exception handling

### WorkflowStep

Defines individual steps within workflow definitions.

**Primary Key**: `workflow_step_id`

**Key Attributes**:
- `workflow_definition_id` - Parent workflow
- `step_name` - Human-readable step name
- `step_order` - Execution sequence
- `step_type` - Type (VALIDATION, ENRICHMENT, APPROVAL, NOTIFICATION, etc.)
- `is_mandatory` - Whether step can be skipped
- `auto_execute` - Whether manual intervention required
- `timeout_minutes` - Step-level timeout
- `retry_count` - Maximum retry attempts
- `prerequisite_steps` - Dependencies (JSON array)
- `configuration` - Step-specific settings (JSON)

**Business Rules:**
- Steps execute in defined order
- Prerequisites must complete before step starts
- Retry logic handles transient failures
- Mandatory steps cannot be bypassed
- Configuration allows step customization

### WorkflowTask

Tracks execution of individual workflow steps.

**Primary Key**: `workflow_task_id`

**Key Attributes**:
- `workflow_instance_id` / `workflow_step_id` - Parent references
- `task_status` - Current status (PENDING, RUNNING, COMPLETED, FAILED, SKIPPED)
- `assigned_to` - User or system responsible
- `started_date` / `completed_date` - Execution timeline
- `retry_attempts` - Number of retries performed
- `result_data` - Task output (JSON)
- `error_details` - Failure information

**Business Rules:**
- Task lifecycle tied to step definition
- Assignment enables workload distribution
- Result data passed to subsequent steps
- Retry tracking for reliability
- Error details support debugging

### Exception

Centralized exception tracking and management.

**Primary Key**: `exception_id`

**Key Attributes**:
- `exception_type` - Classification (VALIDATION_ERROR, SETTLEMENT_FAIL, SYSTEM_ERROR, etc.)
- `severity_level` - Impact level (LOW, MEDIUM, HIGH, CRITICAL)
- `entity_type` / `entity_id` - Associated business entity
- `exception_status` - Current status (NEW, IN_PROGRESS, RESOLVED, ESCALATED)
- `exception_message` - Human-readable description
- `exception_details` - Technical details (JSON)
- `workflow_instance_id` - Related workflow if applicable
- `assigned_to` - Person/team handling exception
- `auto_retry` - Whether automatic retry enabled
- `retry_count` / `max_retries` - Retry management
- `escalation_date` / `resolved_date` - Timeline tracking

**Business Rules:**
- Severity determines handling priority
- Auto-retry for transient issues
- Escalation ensures timely resolution
- Status tracking enables reporting
- Association with entities and workflows

### ExceptionRule

Defines automated exception handling policies.

**Primary Key**: `exception_rule_id`

**Key Attributes**:
- `rule_name` - Human-readable rule name
- `exception_type` / `entity_type` / `severity_level` - Matching criteria
- `rule_condition` - Additional matching logic (JSON)
- `action_type` - Action to take (AUTO_RETRY, ESCALATE, NOTIFY, ASSIGN)
- `action_configuration` - Action-specific settings (JSON)
- `retry_delay_minutes` - Wait time between retries
- `escalation_delay_hours` - Time before escalation
- `notification_recipients` - Alert recipients (JSON array)
- `is_active` - Whether rule is enabled

**Business Rules:**
- Rules processed in priority order
- Conditions enable complex matching
- Actions support various response types
- Timing controls manage workload
- Active flag enables rule management

### STPRule

Defines criteria for straight-through processing eligibility.

**Primary Key**: `stp_rule_id`

**Key Attributes**:
- `rule_name` - Descriptive rule name
- `entity_type` - Applicable entity type
- `rule_category` - Category (VALIDATION, SETTLEMENT, APPROVAL, etc.)
- `rule_condition` - Eligibility criteria (JSON)
- `auto_process` - Whether to process automatically
- `bypass_manual_check` - Skip manual review
- `processing_priority` - Order of rule evaluation
- `tolerance_thresholds` - Acceptable variance levels (JSON)
- `business_hours_only` - Time-based processing restriction
- `is_active` - Rule enablement status

**Business Rules:**
- Rules determine STP eligibility
- Conditions support complex logic
- Priority affects evaluation order
- Tolerances define acceptable variance
- Business hours restriction for risk management

### STPStatus

Tracks straight-through processing status for entities.

**Primary Key**: `stp_status_id`

**Key Attributes**:
- `entity_type` / `entity_id` - Associated business entity
- `stp_eligible` - Whether entity qualifies for STP
- `eligibility_reason` - Explanation of eligibility determination
- `processing_status` - Current status (ELIGIBLE, PROCESSING, COMPLETED, MANUAL_REVIEW)
- `stp_percentage` - Degree of automation achieved
- `manual_steps_required` - Outstanding manual tasks (JSON array)
- `processing_started_date` / `processing_completed_date` - Timeline
- `workflow_instance_id` - Associated workflow

**Business Rules:**
- Eligibility determined by STP rules
- Percentage tracks automation level
- Manual steps identify bottlenecks
- Integration with workflow management
- Status progression tracking

### ProcessingRule

Defines business logic for automated processing.

**Primary Key**: `processing_rule_id`

**Key Attributes**:
- `rule_name` - Descriptive name
- `rule_type` - Type (VALIDATION, ENRICHMENT, TRANSFORMATION, etc.)
- `entity_type` - Applicable entity
- `rule_expression` - Business logic expression
- `action_configuration` - Action settings (JSON)
- `execution_order` - Processing sequence
- `is_blocking` - Whether rule blocks processing on failure
- `error_handling` - Failure response (EXCEPTION, WARNING, IGNORE)
- `is_active` - Rule enablement

**Business Rules:**
- Expressions define business logic
- Execution order ensures consistency
- Blocking rules enforce data quality
- Error handling manages failures
- Active management enables rule updates

### ReconciliationRun

Tracks reconciliation process executions.

**Primary Key**: `recon_run_id`

**Key Attributes**:
- `recon_type` - Type (TRADE_RECON, POSITION_RECON, CASH_RECON, etc.)
- `recon_frequency` - Schedule (DAILY, WEEKLY, MONTHLY, ADHOC)
- `business_date` - Business date being reconciled
- `run_status` - Status (RUNNING, COMPLETED, FAILED, CANCELLED)
- `source_system` / `target_system` - Systems being reconciled
- `total_records_processed` / `matched_records` / `unmatched_records` - Statistics
- `breaks_identified` - Number of breaks found
- `tolerance_amount` - Acceptable variance threshold
- `started_date` / `completed_date` - Execution timeline
- `run_duration_seconds` - Performance metrics
- `configuration` - Run-specific settings (JSON)

**Business Rules:**
- Each run reconciles specific business date
- Statistics track matching effectiveness
- Tolerance defines break sensitivity
- Performance tracking for optimization
- Configuration enables customization

### ReconciliationBreak

Tracks individual reconciliation differences.

**Primary Key**: `recon_break_id`

**Key Attributes**:
- `recon_run_id` - Parent reconciliation run
- `break_type` - Type (AMOUNT_DIFFERENCE, QUANTITY_DIFFERENCE, MISSING_TRADE, etc.)
- `entity_type` / `entity_id` - Associated business entity
- `break_status` - Status (OPEN, INVESTIGATING, EXPLAINED, RESOLVED)
- `break_amount` / `break_currency` - Monetary difference
- `source_value` / `target_value` - Differing values
- `break_description` - Human-readable explanation
- `investigation_notes` - Research findings
- `resolution_action` - How break was resolved
- `assigned_to` - Person investigating
- `age_in_days` - Time since identification
- `resolved_date` - Resolution timestamp
- `exception_id` - Related exception if created

**Business Rules:**
- Breaks represent reconciliation differences
- Status tracks investigation progress
- Age tracking for SLA management
- Association with exceptions for workflow
- Resolution tracking for audit

### ReconciliationRule

Defines matching and tolerance rules for reconciliation.

**Primary Key**: `recon_rule_id`

**Key Attributes**:
- `rule_name` - Descriptive name
- `recon_type` - Applicable reconciliation type
- `matching_criteria` - Fields to match (JSON)
- `tolerance_rules` - Acceptable variances (JSON)
- `break_classification` - How to classify breaks (JSON)
- `auto_resolution_rules` - Automatic resolution logic (JSON)
- `priority_order` - Rule evaluation sequence
- `is_active` - Rule enablement
- `effective_date` / `expiry_date` - Rule validity period

**Business Rules:**
- Matching criteria define comparison logic
- Tolerances determine break sensitivity
- Classification enables break categorization
- Auto-resolution reduces manual effort
- Priority ensures correct rule application
- Date range enables temporal rule management

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
