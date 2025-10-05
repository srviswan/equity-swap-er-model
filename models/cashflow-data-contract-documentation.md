# Cashflow Data Product Contract Documentation

## Overview

The Cashflow Data Product Contract defines a comprehensive, flexible schema for financial contract management and cashflow calculations. This contract accommodates various contract types, payout structures, and calculation methodologies while maintaining consistency with CDM (Common Domain Model) principles.

## Contract Version
- **Version**: 1.0.0
- **Schema**: JSON Schema Draft 2020-12
- **API Specification**: OpenAPI 3.0.3
- **Last Updated**: 2024-12-19

## Key Features

### 1. Enhanced Cashflow Summary and Detailed Breakdowns
The contract now provides comprehensive cashflow reporting with both consolidated summaries and granular details:

#### **Consolidated Summary**
- **Total Cashflow**: Overall monetary value across all payouts
- **Summary by Type**: Grouped by interest, dividend, performance, and principal amounts
- **Summary by Payout**: Individual payout totals with breakdown of accrued, paid, and pending amounts
- **Calculation Period**: Complete period coverage with day counts and business days

#### **Detailed Breakdowns**
- **Daily Breakdown**: Day-by-day cashflow tracking with cumulative amounts
- **Accrual Schedule**: Detailed accrual entries with rates, day counts, and fractions
- **Cashflow Schedule**: Scheduled payments with status tracking (scheduled, paid, overdue, cancelled)
- **Interest Breakdown**: Granular interest calculations with reset dates and rates

#### **Configurable Granularity**
- **Daily**: Most granular level for precise tracking
- **Weekly**: Weekly aggregation for trend analysis
- **Monthly**: Monthly summaries for reporting
- **Quarterly**: Quarterly aggregations for financial reporting
- **Period**: Custom period-based groupings

### 2. Flexible Contract Types
The contract supports multiple financial instrument types:
- **Equity Swap**: Exchange of equity returns for interest payments
- **Interest Rate Swap**: Exchange of fixed for floating interest rates
- **Total Return Swap**: Exchange of total returns including dividends
- **Currency Swap**: Exchange of principal and interest in different currencies
- **Credit Default Swap**: Protection against credit events
- **Commodity Swap**: Exchange based on commodity price movements

### 2. Polymorphic Payout Structures
Supports different payout types with specialized properties:

#### Interest Rate Payouts
- **Fixed Rate**: Constant interest rate over the contract term
- **Floating Rate**: Variable rate based on market indices (SOFR, LIBOR, EURIBOR)
- **Quantity Schedules**: Dynamic notional amounts that change over time
- **Day Count Conventions**: Flexible calculation methods (ACT/360, ACT/365, 30/360)

#### Performance Payouts
- **Price Return Terms**: Absolute or percentage-based returns
- **Dividend Return Terms**: Dividend-related calculations
- **Equity Performance**: Stock price appreciation/depreciation

#### Dividend Payouts
- **Dividend Amount**: Fixed dividend payments
- **Dividend Dates**: Ex-dividend and payment dates
- **Currency Support**: Multi-currency dividend handling

#### Principal Payouts
- **Principal Amount**: Principal exchange amounts
- **Settlement Terms**: Principal settlement conditions

### 3. Dynamic Quantity Schedules
Advanced feature for contracts with varying notional amounts:
```json
{
  "quantitySchedule": {
    "unit": {
      "currency": "USD",
      "financialUnit": "SHARES"
    },
    "quantitySteps": [
      {
        "date": "2024-01-01",
        "quantity": 1000000
      },
      {
        "date": "2024-06-01", 
        "quantity": 1500000
      }
    ]
  }
}
```

### 4. Comprehensive Market Data Integration
Flexible market data structure supporting:
- **Interest Rates**: SOFR, LIBOR, EURIBOR, and custom indices
- **Asset Prices**: Real-time and historical pricing data
- **Dividend Data**: Ex-dates, payment dates, amounts
- **Volatility Data**: For derivatives pricing

### 5. Configurable Calculation Options
Extensive calculation configuration:
- **Day Count Conventions**: Multiple industry standards
- **Precision Control**: Configurable decimal precision (2-16 digits)
- **Calculation Methods**: Simple, Complex, or CDM-inspired
- **Timezone Support**: Global timezone handling
- **Performance Toggles**: Selective calculation components
- **Detailed Breakdowns**: Configurable granularity (daily, weekly, monthly, quarterly)
- **Accrual Schedules**: Detailed accrual tracking and reporting
- **Cashflow Schedules**: Scheduled payment tracking and status

## Schema Structure

### Core Entities

#### Contract
The central entity representing a financial contract:
```json
{
  "contractId": "SWAP_001",
  "contractType": "EQUITY_SWAP",
  "tradeDate": "2024-01-01",
  "effectiveDate": "2024-01-15",
  "maturityDate": "2025-01-15",
  "currency": "USD",
  "status": "ACTIVE",
  "notionalAmount": {
    "value": 1000000,
    "currency": "USD"
  },
  "counterpartyId": "CP_001",
  "payouts": [...]
}
```

#### Payout (Polymorphic)
Base payout structure with specialized subtypes:
```json
{
  "payoutId": "PAYOUT_001",
  "payoutType": "INTEREST_RATE",
  "payerId": "PARTY_A",
  "receiverId": "PARTY_B",
  // Type-specific properties follow
}
```

#### Money
Standardized monetary value representation:
```json
{
  "value": 1000000.50,
  "currency": "USD",
  "unit": "SHARES"
}
```

### Enhanced Response Structures

#### CashflowSummary
Comprehensive summary with detailed breakdowns:
```json
{
  "totalCashflow": {
    "value": 125000.50,
    "currency": "USD"
  },
  "summaryByType": {
    "interestAmount": {
      "value": 75000.25,
      "currency": "USD"
    },
    "performanceAmount": {
      "value": 50000.25,
      "currency": "USD"
    }
  },
  "summaryByPayout": [
    {
      "payoutId": "FLOATING_LEG",
      "payoutType": "INTEREST_RATE",
      "totalAmount": {
        "value": 75000.25,
        "currency": "USD"
      },
      "breakdown": {
        "accruedAmount": {
          "value": 45000.15,
          "currency": "USD"
        },
        "paidAmount": {
          "value": 30000.10,
          "currency": "USD"
        },
        "pendingAmount": {
          "value": 0.00,
          "currency": "USD"
        }
      }
    }
  ],
  "calculationPeriod": {
    "startDate": "2024-03-15",
    "endDate": "2024-06-15",
    "totalDays": 92,
    "businessDays": 65,
    "accrualDays": 92
  },
  "detailedBreakdown": {
    "dailyBreakdown": [...],
    "accrualSchedule": [...],
    "cashflowSchedule": [...],
    "interestBreakdown": [...]
  }
}
```

#### DailyCashflowEntry
Daily granular cashflow tracking:
```json
{
  "date": "2024-06-01",
  "totalAmount": {
    "value": 815.22,
    "currency": "USD"
  },
  "interestAmount": {
    "value": 815.22,
    "currency": "USD"
  },
  "accruedAmount": {
    "value": 815.22,
    "currency": "USD"
  },
  "cumulativeAmount": {
    "value": 75000.25,
    "currency": "USD"
  }
}
```

#### AccrualEntry
Detailed accrual tracking:
```json
{
  "payoutId": "FLOATING_LEG",
  "startDate": "2024-03-15",
  "endDate": "2024-06-15",
  "accruedAmount": {
    "value": 45000.15,
    "currency": "USD"
  },
  "notionalAmount": {
    "value": 1000000,
    "currency": "USD"
  },
  "rate": 0.045,
  "dayCount": 92,
  "dayCountFraction": 0.2556
}
```

#### InterestBreakdownEntry
Detailed interest calculation tracking:
```json
{
  "payoutId": "FLOATING_LEG",
  "periodStart": "2024-03-15",
  "periodEnd": "2024-06-15",
  "interestAmount": {
    "value": 45000.15,
    "currency": "USD"
  },
  "notionalAmount": {
    "value": 1000000,
    "currency": "USD"
  },
  "rate": 0.045,
  "dayCount": 92,
  "dayCountFraction": 0.2556,
  "calculationMethod": "CDM_INSPIRED",
  "resetDate": "2024-03-15",
  "resetRate": 0.045
}
```

### API Endpoints

#### Single Contract Calculation
```http
POST /calculations/single
Content-Type: application/json

{
  "contract": { ... },
  "calculationDate": "2024-06-15",
  "marketData": { ... },
  "options": { ... }
}
```

#### Batch Contract Calculation
```http
POST /calculations/batch
Content-Type: application/json

{
  "contracts": [ ... ],
  "calculationDate": "2024-06-15",
  "marketData": { ... },
  "options": { ... }
}
```

#### Contract Management
```http
GET /contracts?status=ACTIVE&contractType=EQUITY_SWAP&limit=100
GET /contracts/{contractId}
```

#### Market Data Access
```http
GET /market-data?date=2024-06-15&include=rates,prices,dividends
```

## Validation Rules

### Contract Validation
- **Contract ID**: Must be unique, alphanumeric with underscores/hyphens
- **Dates**: Trade date ≤ Effective date ≤ Maturity date
- **Currency**: Must be valid 3-letter ISO currency code
- **Notional Amount**: Must be positive
- **Payouts**: At least one payout required

### Payout Validation
- **Interest Rate Payouts**: Rate specification required
- **Floating Rate**: Index and spread required
- **Quantity Schedule**: Valid date sequence required
- **Performance Payouts**: Return terms required

### Market Data Validation
- **Rates**: Must be non-negative
- **Prices**: Must be positive
- **Dividends**: Valid date sequences required

## Error Handling

### Standard Error Response
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Invalid contract data provided",
  "timestamp": "2024-06-15T10:30:00Z",
  "details": {
    "field": "contract.payouts[0].rateSpecification.rate",
    "reason": "Rate must be between 0 and 1"
  },
  "requestId": "req_123456789"
}
```

### Error Types
- **VALIDATION_ERROR**: Input data validation failures
- **CALCULATION_ERROR**: Calculation processing errors
- **MARKET_DATA_ERROR**: Market data access/processing errors
- **SYSTEM_ERROR**: Internal system errors

## Usage Examples

### Example 1: Equity Swap with Floating Rate
```json
{
  "contract": {
    "contractId": "EQ_SWAP_001",
    "contractType": "EQUITY_SWAP",
    "tradeDate": "2024-01-01",
    "effectiveDate": "2024-01-15",
    "maturityDate": "2025-01-15",
    "currency": "USD",
    "status": "ACTIVE",
    "notionalAmount": {
      "value": 1000000,
      "currency": "USD"
    },
    "counterpartyId": "CP_001",
    "payouts": [
      {
        "payoutId": "FLOATING_LEG",
        "payoutType": "INTEREST_RATE",
        "payerId": "PARTY_A",
        "receiverId": "PARTY_B",
        "notionalAmount": {
          "value": 1000000,
          "currency": "USD"
        },
        "rateSpecification": {
          "rateType": "FLOATING",
          "floatingRateIndex": "SOFR",
          "spread": 0.005,
          "resetFrequency": "QUARTERLY"
        },
        "currency": "USD",
        "dayCountConvention": "ACT/360",
        "paymentFrequency": "QUARTERLY"
      },
      {
        "payoutId": "EQUITY_LEG",
        "payoutType": "PERFORMANCE",
        "payerId": "PARTY_B",
        "receiverId": "PARTY_A",
        "returnTerms": {
          "priceReturnTerms": {
            "priceReturn": {
              "returnType": "PERCENTAGE"
            }
          }
        }
      }
    ]
  },
  "calculationDate": "2024-06-15",
  "marketData": {
    "rates": {
      "SOFR": 0.045
    },
    "prices": {
      "SPY": {
        "value": 450.50,
        "currency": "USD",
        "date": "2024-06-15"
      }
    }
  },
  "options": {
    "includeDividends": true,
    "dayCountConvention": "ACT/360",
    "precision": 8,
    "calculationMethod": "CDM_INSPIRED"
  }
}
```

### Example 2: Enhanced Response with Summary and Detailed Breakdowns
```json
{
  "contractId": "EQ_SWAP_001",
  "calculationDate": "2024-06-15",
  "totalCashflow": {
    "value": 125000.50,
    "currency": "USD"
  },
  "payoutResults": [
    {
      "payoutId": "FLOATING_LEG",
      "payoutType": "INTEREST_RATE",
      "cashflowAmount": {
        "value": 75000.25,
        "currency": "USD"
      },
      "calculationStatus": "SUCCESS"
    },
    {
      "payoutId": "EQUITY_LEG",
      "payoutType": "PERFORMANCE",
      "cashflowAmount": {
        "value": 50000.25,
        "currency": "USD"
      },
      "calculationStatus": "SUCCESS"
    }
  ],
  "calculationStatus": "SUCCESS",
  "calculatedAt": "2024-06-15T10:30:00Z",
  "processingTimeMs": 150,
  "cashflowSummary": {
    "totalCashflow": {
      "value": 125000.50,
      "currency": "USD"
    },
    "summaryByType": {
      "interestAmount": {
        "value": 75000.25,
        "currency": "USD"
      },
      "performanceAmount": {
        "value": 50000.25,
        "currency": "USD"
      }
    },
    "summaryByPayout": [
      {
        "payoutId": "FLOATING_LEG",
        "payoutType": "INTEREST_RATE",
        "totalAmount": {
          "value": 75000.25,
          "currency": "USD"
        },
        "breakdown": {
          "accruedAmount": {
            "value": 45000.15,
            "currency": "USD"
          },
          "paidAmount": {
            "value": 30000.10,
            "currency": "USD"
          },
          "pendingAmount": {
            "value": 0.00,
            "currency": "USD"
          }
        }
      }
    ],
    "calculationPeriod": {
      "startDate": "2024-03-15",
      "endDate": "2024-06-15",
      "totalDays": 92,
      "businessDays": 65,
      "accrualDays": 92
    },
    "detailedBreakdown": {
      "dailyBreakdown": [
        {
          "date": "2024-06-01",
          "totalAmount": {
            "value": 815.22,
            "currency": "USD"
          },
          "interestAmount": {
            "value": 815.22,
            "currency": "USD"
          },
          "accruedAmount": {
            "value": 815.22,
            "currency": "USD"
          },
          "cumulativeAmount": {
            "value": 75000.25,
            "currency": "USD"
          }
        }
      ],
      "accrualSchedule": [
        {
          "payoutId": "FLOATING_LEG",
          "startDate": "2024-03-15",
          "endDate": "2024-06-15",
          "accruedAmount": {
            "value": 45000.15,
            "currency": "USD"
          },
          "notionalAmount": {
            "value": 1000000,
            "currency": "USD"
          },
          "rate": 0.045,
          "dayCount": 92,
          "dayCountFraction": 0.2556
        }
      ],
      "cashflowSchedule": [
        {
          "payoutId": "FLOATING_LEG",
          "paymentDate": "2024-06-15",
          "amount": {
            "value": 30000.10,
            "currency": "USD"
          },
          "status": "PAID",
          "paymentType": "INTEREST"
        }
      ],
      "interestBreakdown": [
        {
          "payoutId": "FLOATING_LEG",
          "periodStart": "2024-03-15",
          "periodEnd": "2024-06-15",
          "interestAmount": {
            "value": 45000.15,
            "currency": "USD"
          },
          "notionalAmount": {
            "value": 1000000,
            "currency": "USD"
          },
          "rate": 0.045,
          "dayCount": 92,
          "dayCountFraction": 0.2556,
          "calculationMethod": "CDM_INSPIRED",
          "resetDate": "2024-03-15",
          "resetRate": 0.045
        }
      ]
    }
  }
}
```

### Example 3: Interest Rate Swap with Quantity Schedule
```json
{
  "contract": {
    "contractId": "IRS_SCHEDULE_001",
    "contractType": "INTEREST_RATE_SWAP",
    "tradeDate": "2024-01-01",
    "effectiveDate": "2024-01-15",
    "maturityDate": "2026-01-15",
    "currency": "USD",
    "status": "ACTIVE",
    "notionalAmount": {
      "value": 1000000,
      "currency": "USD"
    },
    "counterpartyId": "CP_002",
    "payouts": [
      {
        "payoutId": "FIXED_LEG",
        "payoutType": "INTEREST_RATE",
        "payerId": "PARTY_A",
        "receiverId": "PARTY_B",
        "notionalAmount": {
          "value": 1000000,
          "currency": "USD"
        },
        "rateSpecification": {
          "rateType": "FIXED",
          "rate": 0.025
        },
        "currency": "USD",
        "dayCountConvention": "30/360",
        "paymentFrequency": "SEMI_ANNUAL"
      },
      {
        "payoutId": "FLOATING_LEG",
        "payoutType": "INTEREST_RATE",
        "payerId": "PARTY_B",
        "receiverId": "PARTY_A",
        "rateSpecification": {
          "rateType": "FLOATING",
          "floatingRateIndex": "SOFR",
          "spread": 0.002
        },
        "currency": "USD",
        "dayCountConvention": "ACT/360",
        "paymentFrequency": "QUARTERLY",
        "quantitySchedule": {
          "unit": {
            "currency": "USD"
          },
          "quantitySteps": [
            {
              "date": "2024-01-15",
              "quantity": 1000000
            },
            {
              "date": "2024-07-15",
              "quantity": 1200000
            },
            {
              "date": "2025-01-15",
              "quantity": 1100000
            }
          ]
        }
      }
    ]
  },
  "calculationDate": "2024-09-15",
  "marketData": {
    "rates": {
      "SOFR": 0.042
    }
  },
  "options": {
    "dayCountConvention": "ACT/360",
    "precision": 6,
    "calculationMethod": "CDM_INSPIRED"
  }
}
```

## Performance Considerations

### Batch Processing
- **Maximum Batch Size**: 1,000 contracts per request
- **Parallel Processing**: Contracts processed concurrently
- **Timeout Handling**: 30-second timeout per batch
- **Resource Management**: Memory-efficient processing

### Caching Strategy
- **Market Data**: 5-minute cache for rates and prices
- **Calculation Results**: 1-hour cache for identical inputs
- **Contract Data**: No caching (always fresh data)

### Rate Limiting
- **Single Calculations**: 100 requests per minute
- **Batch Calculations**: 10 requests per minute
- **Market Data**: 1,000 requests per minute

## Security

### Authentication
- **API Key**: Required for all endpoints
- **JWT Tokens**: Optional for enhanced security
- **Rate Limiting**: Per-client limits enforced

### Data Privacy
- **PII Protection**: No personally identifiable information stored
- **Data Encryption**: TLS 1.3 for all communications
- **Audit Logging**: All requests logged for compliance

## Compliance

### Regulatory Standards
- **ISO 20022**: Message format compatibility
- **FIX Protocol**: Trading message support
- **MiFID II**: European regulation compliance
- **Dodd-Frank**: US regulation compliance

### Data Governance
- **Data Lineage**: Full calculation traceability
- **Version Control**: Schema versioning support
- **Change Management**: Controlled schema evolution

## Migration Guide

### From Version 0.x to 1.0.0
1. **Update Payout Structure**: Add required `payoutType` discriminator
2. **Enhance Rate Specifications**: Use new polymorphic structure
3. **Add Market Data**: Include market data in calculation requests
4. **Update Error Handling**: Use new error response format

### Backward Compatibility
- **Deprecation Period**: 6 months for breaking changes
- **Version Headers**: Support multiple API versions
- **Migration Tools**: Automated migration scripts available

## Support and Resources

### Documentation
- **API Reference**: Complete endpoint documentation
- **Schema Explorer**: Interactive schema browser
- **Code Examples**: Sample implementations in multiple languages

### Community
- **GitHub Repository**: Open source components
- **Slack Channel**: Real-time support
- **User Forums**: Community discussions

### Professional Services
- **Implementation Support**: Custom integration assistance
- **Training Programs**: Comprehensive training courses
- **Consulting Services**: Architecture and best practices guidance

## Changelog

### Version 1.0.0 (2024-12-19)
- Initial release of comprehensive data contract
- Support for all major contract types
- Polymorphic payout structures
- Dynamic quantity schedules
- Comprehensive market data integration
- Full OpenAPI 3.0.3 specification
- Complete validation rules
- Extensive documentation and examples
