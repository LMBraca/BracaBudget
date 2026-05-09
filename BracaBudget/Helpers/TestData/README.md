# Test Data Documentation

## Overview
The test data loader creates comprehensive data for testing all BracaBudget features, especially rollback functionality and budget calculations.

## Test Data Scenarios

### Categories (20 total)
- **15 Expense Categories**: Housing, Groceries, Dining Out, Transport, Gas, Health, Entertainment, Shopping, Education, Travel, Utilities, Subscriptions, Personal Care, Pets, Other
- **5 Income Categories**: Salary, Freelance, Investment, Gift, Other Income

Note: These match the default categories from SeedData.swift for consistency.

### Allocations (5 total)
1. **Groceries** - $400/month
2. **Gas** - $150/month
3. **Dining Out** - $200/month
4. **Entertainment** - $75/week
5. **Shopping** - $150/month

### Transactions

#### Current Month Transactions (~20 transactions)
Distributed across 4 weeks to test:
- Weekly spending calculations
- Monthly budget tracking
- Category-based allocations

**Week 1** (25-22 days ago):
- Groceries, Gas, Netflix, Dining Out

**Week 2** (18-14 days ago):
- Groceries, Movies, Amazon shopping, Spotify

**Week 3** (11-7 days ago):
- Internet, Groceries, Uber, Dining Out, Gas

**Week 4 - Current Week** (4-0 days ago):
- Costco groceries, Target, Starbucks, Gym, Steam, Panera

#### Income Transactions
- Monthly Salary: $4,500 (28 days ago)
- Freelance Project: $850 (14 days ago)

#### Previous Month Transactions (~4 transactions)
For testing historical rollbacks:
- Groceries, Gas, Netflix (30+ days ago)
- Previous month's salary

#### Future Transaction (1 transaction)
- Scheduled grocery trip (tomorrow) - Should NOT affect current calculations

## Rollback Test Scenarios

### Scenario 1: Weekly Rollback
Delete transactions from current week to see weekly available amount increase.

### Scenario 2: Monthly Rollback
Delete transactions from previous weeks to test monthly limit tracking.

### Scenario 3: Allocation Category Rollback
Delete Groceries, Gas, or Dining Out transactions to see:
- Allocation progress bars update
- Category totals recalculate
- Budget math adjusts if it's a monthly allocation

### Scenario 4: Income Rollback
Delete salary or freelance income to test income tracking.

### Scenario 5: Multi-Period Rollback
Delete transactions spanning multiple weeks/months to verify date-based filtering.

## How to Use

1. Build in DEBUG mode
2. Go to Settings
3. Tap "Load Test Data" under Developer Tools
4. Confirm the dialog
5. Navigate through the app to see populated data
6. Test rollbacks by deleting transactions and observing updates

## Expected Budget Calculations

With test data loaded:
- **Monthly Envelope**: You'll need to set this in Settings
- **Allocated**: $900/month (Groceries + Gas + Dining + Shopping) + Weekly Entertainment
- **Discretionary Pool**: Envelope - Allocated
- **Weekly Allowance**: Pool ÷ weeks in month

## Notes

- Test data is only available in DEBUG builds
- Loading test data deletes ALL existing data
- Categories are marked as default and cannot be deleted
- Dates are calculated relative to today for consistent testing
