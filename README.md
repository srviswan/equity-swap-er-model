# Equity Swap ER Model

## Overview

This project contains an Entity-Relationship (ER) model for managing an equity swap management system based on the FINOS Common Domain Model (CDM) Rosetta specification. The ER model captures the essential entities, relationships, and attributes needed to manage the complete lifecycle of equity swap trades.

## CDM Reference

This ER model is derived from the FINOS CDM, specifically referencing:
- CDM Version: 5.x (master-SNAPSHOT)
- Key CDM Modules:
  - `event-common-type.rosetta` - Core trade and event structures
  - `product-template-type.rosetta` - Product and trade lot definitions
  - `product-qualification-func.rosetta` - Equity swap classifications
  - `product-asset-type.rosetta` - Asset and performance specifications

## Key Features

The equity swap management system ER model supports:

1. **Trade Lifecycle Management**
   - Trade creation and execution
   - Position tracking and updates
   - Event processing (resets, terminations, etc.)
   - Valuation and pricing

2. **Equity Swap Types**
   - Price Return Basic Performance (Single Name, Index, Basket)
   - Total Return Basic Performance (Single Name, Index, Basket)
   - Parameter Return (Variance, Volatility, Dispersion)
   - Cross-Currency Swaps with FX reset mechanisms

3. **Party and Role Management**
   - Counterparty identification
   - Ancillary parties (calculation agents, etc.)
   - Role-based permissions

4. **Settlement and Collateral**
   - Settlement instructions
   - Collateral management
   - Margin calculations

## Project Structure

```
equity-swap-er-model/
├── README.md                    # This file
├── docs/
│   ├── er-diagram.md           # Detailed ER diagram description
│   ├── entity-definitions.md   # Entity descriptions and attributes
│   └── relationships.md        # Relationship definitions
├── sql/
│   ├── create-tables.sql       # Database schema creation
│   ├── sample-data.sql         # Sample test data
│   └── views.sql              # Useful database views
├── models/
│   ├── conceptual-model.plantuml  # PlantUML ER diagram
│   └── logical-model.json      # JSON representation
└── examples/
    ├── apple-total-return-swap.json      # Single-name total return swap
    ├── tech-basket-variance-swap.json    # Multi-stock variance swap
    ├── sp500-price-return-swap.json      # Index-based price return swap
    ├── cross-currency-nikkei-swap.json   # Cross-currency international swap
    └── use-cases.md                     # Common use cases
```

## Getting Started

1. Review the [ER Diagram](docs/er-diagram.md) for an overview of the model
2. Check [Entity Definitions](docs/entity-definitions.md) for detailed entity specifications
3. Examine [Sample Data](sql/sample-data.sql) for example equity swap records
4. Refer to [Use Cases](examples/use-cases.md) for common scenarios

## Database Implementation

The ER model can be implemented in various database systems:
- PostgreSQL (recommended for complex financial data)
- MySQL
- Oracle Database
- SQL Server

See the `sql/` directory for implementation scripts.

## Cross-Currency Features

The model includes comprehensive support for cross-currency equity swaps:

### FX Rate Management
- **FXRate Entity**: Tracks exchange rates with multiple sources and types
- **CurrencyPair Entity**: Defines market conventions for currency pairs
- **Rate Types**: Support for SPOT, FORWARD, IMPLIED, and FIXING rates
- **Historical Rates**: Complete audit trail of rate changes

### FX Reset Mechanisms
- **FXResetEvent Entity**: Manages FX fixing events and reset schedules
- **Reset Types**: INITIAL, PERIODIC, FINAL, and BARRIER resets
- **Reset Status**: Tracking from PENDING to FIXED or FAILED
- **Multiple Frequencies**: Daily, weekly, monthly, quarterly, and custom schedules

### Cross-Currency Payout Support
- **Multi-Currency Settlements**: Different currencies for calculation and settlement
- **FX Reset Required**: Automatic identification of FX-dependent payouts
- **Rate Source Configuration**: Configurable rate sources (WM/Reuters, ECB, etc.)
- **Fixing Time Management**: Precise timing for rate fixings

### Example Use Cases
- **Nikkei 225 JPY/USD Swap**: Japanese equity with USD settlement
- **European Equity EUR/USD Swap**: Euro-denominated equity with USD settlement
- **Multi-Currency Baskets**: Baskets with mixed currency exposures
- **Currency Hedged Swaps**: Equity exposure with FX hedging components

## Integration

This ER model is designed to integrate with:
- CDM-compliant systems
- Risk management platforms
- Trading systems
- Regulatory reporting tools
- FX rate providers (Bloomberg, Reuters, ECB)

## License

This project follows the same licensing as the FINOS CDM project.
