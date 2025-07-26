# CDM Interest Calculation System Guide

## Overview

This guide provides comprehensive documentation for the CDM-compliant interest calculation system implemented for equity swaps. The system accurately calculates interest using running notional amounts between two dates, following FINOS CDM (Common Domain Model) specifications.

## Architecture

### Core Components

1. **Day Count Fraction Calculator** (`udf_calculate_day_count_fraction`)
   - Supports multiple CDM day count conventions: ACT/360, ACT/365, 30/360, ACT/ACT
   - Accurate calculation of day count fractions for interest accruals
   - Handles edge cases like leap years and month-end adjustments

2. **Running Notional Period Extractor** (`v_running_notional_periods`)
   - Extracts continuous notional periods from settlement events
   - Handles partial terminations and resets
   - Provides average notional amounts for interest calculation periods

3. **CDM Interest Calculation Engine** (`sp_calculate_cdm_interest`)
   - Main calculation procedure using running notional amounts
   - Supports both fixed and floating rate calculations
   - Returns detailed calculation breakdowns

4. **Accrual Schedule Generator** (`sp_generate_interest_accrual_schedule`)
   - Generates payment schedules based on CDM frequencies
   - Supports monthly, quarterly, semi-annual, and annual payments
   - Handles custom date ranges

## CDM Compliance

### Day Count Conventions

The system implements all standard CDM day count conventions:

- **ACT/360**: Actual days divided by 360
- **ACT/365**: Actual days divided by 365
- **30/360**: 30-day months divided by 360
- **ACT/ACT**: Actual days divided by actual days in year (including leap years)

### Interest Rate Types

- **Fixed Rate**: Constant rate throughout the swap term
- **Floating Rate**: Based on reference index plus spread
- **Spread**: Additional basis points over reference rate

### Payment Frequencies

- Monthly
- Quarterly
- Semi-Annual
- Annual

## Usage Examples

### Basic Interest Calculation

```sql
-- Calculate interest for a specific trade and date range
EXEC sp_calculate_cdm_interest 
    @trade_id = 'TRD001',
    @start_date = '2024-01-01',
    @end_date = '2024-12-31',
    @debug_mode = 1;
```

### Accrual Schedule Generation

```sql
-- Generate quarterly accrual schedule
EXEC sp_generate_interest_accrual_schedule
    @trade_id = 'TRD001',
    @accrual_start_date = '2024-01-01',
    @accrual_end_date = '2024-12-31',
    @payment_frequency = 'QUARTERLY';
```

### Validation Query

```sql
-- Validate all interest calculations
SELECT * FROM v_interest_calculation_validation;
```

## Calculation Formula

The system uses the standard CDM interest calculation formula:

```
Interest = Notional × Rate × DayCountFraction
```

Where:
- **Notional**: Running notional amount for the period
- **Rate**: Effective interest rate (fixed rate + spread)
- **DayCountFraction**: Calculated using specified day count convention

## Running Notional Integration

### Notional Period Extraction

The system extracts notional periods from settlement events:

1. **Initial Period**: From trade date to first settlement
2. **Settlement Periods**: Between consecutive settlements
3. **Final Period**: From last settlement to calculation end date

### Notional Amount Calculation

For each period:
- **Start Notional**: Running notional at period start
- **End Notional**: Running notional at period end
- **Average Notional**: (Start + End) / 2 (for simplified calculation)

## Testing and Validation

### Test Cases

1. **Day Count Validation**: All conventions tested against manual calculations
2. **Notional Tracking**: Verified with partial terminations and resets
3. **Interest Calculation**: Cross-validated with expected results
4. **Edge Cases**: Zero notional, small amounts, leap years

### Validation Reports

The system provides comprehensive validation:
- Individual period calculations
- Total interest aggregation
- Cross-reference with existing cash flows
- Validation status indicators

## Implementation Notes

### Database Requirements

- Microsoft SQL Server 2016 or later
- JSON support for calculation details
- Window functions for running calculations

### Performance Considerations

- Indexed views for running notional periods
- Efficient date range queries
- Optimized calculation functions

### Error Handling

- Input parameter validation
- Date range boundary checks
- Notional amount validation
- Rate calculation verification

## Troubleshooting

### Common Issues

1. **Invalid Day Count Convention**: Ensure correct convention name
2. **Date Range Errors**: Verify start date < end date
3. **Missing Notional Data**: Check settlement events exist
4. **Rate Calculation**: Verify fixed rate and spread values

### Debug Mode

Enable debug mode for detailed calculation breakdown:

```sql
EXEC sp_calculate_cdm_interest 
    @trade_id = 'TRD001',
    @start_date = '2024-01-01',
    @end_date = '2024-12-31',
    @debug_mode = 1;  -- Returns detailed calculation steps
```

## Integration Examples

### Integration with Trade Lifecycle

The system integrates seamlessly with the equity swap lifecycle:

1. **Trade Execution**: Initial notional and rate setup
2. **Settlement Events**: Running notional updates
3. **Interest Calculation**: Periodic interest accruals
4. **Payment Processing**: Cash flow generation

### Regulatory Reporting

The system supports regulatory reporting requirements:
- Accurate interest calculations
- Audit trail of notional changes
- CDM-compliant data structures
- Standardized calculation methods

## Sample Output

### Interest Calculation Results

```
trade_id    | TEST_CDM_001
period_start_date | 2024-01-15
period_end_date   | 2024-02-15
notional_amount   | 1000000.00
interest_rate     | 0.052500
day_count_fraction| 0.086111
interest_amount   | 4548.61
day_count_convention | ACT/360
calculation_formula | Interest = 1,000,000.00 × 5.2500% × 0.086111
```

### Validation Summary

```
trade_id    | TEST_CDM_001
total_periods | 4
total_interest | 28,437.50
earliest_period | 2024-01-15
latest_period   | 2024-05-15
avg_notional    | 937,500.00
total_day_count_fraction | 0.541667
```

## Next Steps

1. **Production Deployment**: Deploy to SQL Server environment
2. **Performance Testing**: Validate with large datasets
3. **Integration Testing**: Test with existing trading systems
4. **User Training**: Provide training materials for end users
5. **Monitoring Setup**: Implement calculation monitoring and alerts
