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
    ├── equity-swap-samples.json   # Sample equity swap data
    └── use-cases.md              # Common use cases
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

## Integration

This ER model is designed to integrate with:
- CDM-compliant systems
- Risk management platforms
- Trading systems
- Regulatory reporting tools

## License

This project follows the same licensing as the FINOS CDM project.
