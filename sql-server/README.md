# Equity Swap ER Model - MS SQL Server Implementation

This directory contains MS SQL Server compatible versions of all PostgreSQL SQL files from the main equity swap project.

## Key Conversions Made

### Data Type Conversions
- `JSONB` → `NVARCHAR(MAX)` (stored as JSON strings)
- `BOOLEAN` → `BIT` (with 1/0 instead of TRUE/FALSE)
- `TEXT` → `NVARCHAR(MAX)`
- `TIMESTAMP` → `DATETIME2`
- `SERIAL` → `IDENTITY(1,1)` (where applicable)

### Function Conversions
- `CURRENT_DATE` → `CAST(GETDATE() AS DATE)`
- `CURRENT_TIMESTAMP` → `GETDATE()`
- PostgreSQL functions → T-SQL stored procedures
- `LANGUAGE plpgsql` → T-SQL syntax

### JSON Handling
- JSONB operators converted to JSON functions where possible
- Complex JSON validation constraints simplified
- JSON path queries converted to appropriate T-SQL equivalents

## Files Converted

✅ **create-tables.sql** - Core schema tables with data type conversions
✅ **tax-lot-management.sql** - Tax lot and unwind methodology tables  
✅ **unwind-procedures.sql** - Tax lot unwind stored procedure
✅ **trade-relationships.sql** - Trade grouping and basket relationships
✅ **sample-data.sql** - Sample data with proper SQL Server syntax
✅ **tax-lot-queries.sql** - Tax lot methodology queries
✅ **basket-component-queries.sql** - Basket component analysis queries

## Conversion Status: ✅ COMPLETE

All PostgreSQL files have been successfully converted to MS SQL Server compatible versions. The SQL Server implementation includes:

- **7 SQL files** with complete T-SQL syntax
- **All data type conversions** properly implemented
- **Stored procedures** converted from PL/pgSQL to T-SQL
- **Date/time functions** updated for SQL Server
- **JSON handling** adapted to SQL Server capabilities
- **Comprehensive sample data** for testing and validation

### Status Legend
- ✅ Completed
- 🔄 In Progress
- ❌ Not Started

## Usage Notes

### JSON Fields
JSON fields are stored as `NVARCHAR(MAX)` and can be queried using SQL Server's JSON functions:
```sql
-- Check if JSON is valid
SELECT * FROM Party WHERE ISJSON(party_identifiers) = 1;

-- Extract JSON values
SELECT party_name, JSON_VALUE(party_identifiers, '$.lei') as lei
FROM Party WHERE party_identifiers IS NOT NULL;
```

### Boolean Fields
Boolean fields use `BIT` data type:
```sql
-- Query active parties
SELECT * FROM Party WHERE is_active = 1;

-- Update status
UPDATE Party SET is_active = 0 WHERE party_id = 'PARTY001';
```

### Date/Time Functions
```sql
-- Current date
INSERT INTO Trade (trade_date) VALUES (CAST(GETDATE() AS DATE));

-- Current timestamp
INSERT INTO TradeEvent (created_timestamp) VALUES (GETDATE());
```

## Compatibility Notes

### Differences from PostgreSQL Version
1. **JSON Validation**: Less strict JSON validation due to NVARCHAR storage
2. **Array Operations**: Limited array functionality compared to JSONB
3. **Index Types**: Different indexing strategies for JSON fields
4. **Function Syntax**: T-SQL stored procedures instead of PostgreSQL functions

### Performance Considerations
1. **JSON Queries**: Consider creating computed columns for frequently queried JSON attributes
2. **Indexes**: Add appropriate indexes on JSON extracted values
3. **Constraints**: Some complex JSON constraints may need application-level validation

## Installation

1. Run the schema files in order:
   ```sql
   -- Execute these files in SQL Server Management Studio or Azure Data Studio
   :r create-tables.sql
   :r tax-lot-management.sql  
   :r unwind-procedures.sql
   -- Additional files as they become available
   ```

2. Load sample data:
   ```sql
   :r sample-data.sql  -- When available
   ```

3. Test with queries:
   ```sql
   :r tax-lot-queries.sql  -- When available
   ```

## Migration from PostgreSQL

If migrating from an existing PostgreSQL database:

1. **Export Data**: Use appropriate export tools to extract data
2. **Transform JSON**: Convert JSONB to JSON strings
3. **Convert Booleans**: Transform TRUE/FALSE to 1/0
4. **Update Procedures**: Replace function calls with stored procedure calls
5. **Test Thoroughly**: Validate all business logic works correctly

## Support

For issues or questions about the SQL Server implementation, please refer to the main project documentation or create an issue in the repository.
