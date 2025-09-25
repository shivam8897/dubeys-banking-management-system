-- Banking Management System - Complete Setup Script
-- Author: BMS Development Team
-- Description: Complete database setup in correct order

PROMPT 'Starting Banking Management System Database Setup...';
PROMPT '=====================================================';

-- Step 1: Create tables and sequences
PROMPT 'Step 1: Creating tables and sequences...';
@@SQL/tables.sql

-- Step 2: Create functions
PROMPT 'Step 2: Creating functions...';
@@SQL/functions.sql

-- Step 3: Create procedures
PROMPT 'Step 3: Creating procedures...';
@@SQL/procedures.sql

-- Step 4: Create triggers
PROMPT 'Step 4: Creating triggers...';
@@SQL/triggers.sql

-- Step 5: Create packages
PROMPT 'Step 5: Creating packages...';
@@SQL/packages.sql

-- Step 6: Insert sample data
PROMPT 'Step 6: Inserting sample data...';
@@SQL/sample_data.sql

-- Step 7: Performance tuning (optional)
PROMPT 'Step 7: Performance tuning (optional)...';
PROMPT 'Run @SQL/performance_tuning.sql for production optimization';

-- Step 8: Scheduler jobs (optional)
PROMPT 'Step 8: Scheduler jobs (optional)...';
PROMPT 'Run @SQL/scheduler_jobs.sql to enable automated tasks';

PROMPT '';
PROMPT '=====================================================';
PROMPT 'Banking Management System Setup Complete!';
PROMPT '=====================================================';
PROMPT '';
PROMPT 'Next Steps:';
PROMPT '1. Update database connection details in UI/app.py';
PROMPT '2. Install Python dependencies: pip install -r UI/requirements.txt';
PROMPT '3. Run the Flask application: python UI/app.py';
PROMPT '4. Access the web interface at http://localhost:5000';
PROMPT '';
PROMPT 'Sample Data Created:';
PROMPT '- 5 Customers';
PROMPT '- 6 Accounts (4 Savings, 2 Current)';
PROMPT '- Multiple sample transactions';
PROMPT '- 5 Loan applications with different statuses';
PROMPT '';
PROMPT 'Test the system by:';
PROMPT '1. Adding new customers and accounts';
PROMPT '2. Processing deposits, withdrawals, and transfers';
PROMPT '3. Applying for loans and processing applications';
PROMPT '4. Generating various reports';
PROMPT '';

-- Verify setup
SELECT 'Setup Verification' as STATUS FROM DUAL;
SELECT 'CUSTOMERS' as TABLE_NAME, COUNT(*) as RECORD_COUNT FROM CUSTOMERS
UNION ALL
SELECT 'ACCOUNTS', COUNT(*) FROM ACCOUNTS
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM TRANSACTION_HISTORY
UNION ALL
SELECT 'LOANS', COUNT(*) FROM LOANS
UNION ALL
SELECT 'LOAN_PAYMENTS', COUNT(*) FROM LOAN_PAYMENTS
UNION ALL
SELECT 'ACCOUNT_TYPES', COUNT(*) FROM ACCOUNT_TYPES;

PROMPT 'Database setup verification complete!';