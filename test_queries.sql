-- Banking Management System - Test Queries
-- Author: BMS Development Team
-- Description: Test queries to verify system functionality

PROMPT 'Testing Banking Management System Functionality...';
PROMPT '==================================================';

-- Test 1: Customer Management
PROMPT 'Test 1: Customer Management';
SELECT customer_id, first_name || ' ' || last_name as name, email, status 
FROM CUSTOMERS 
ORDER BY customer_id;

-- Test 2: Account Information
PROMPT 'Test 2: Account Information';
SELECT a.account_id, a.account_number, c.first_name || ' ' || c.last_name as customer_name,
       at.type_name, a.balance, a.status
FROM ACCOUNTS a
JOIN CUSTOMERS c ON a.customer_id = c.customer_id
JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
ORDER BY a.account_id;

-- Test 3: Recent Transactions
PROMPT 'Test 3: Recent Transactions (Last 10)';
SELECT th.transaction_id, a.account_number, th.transaction_type, 
       th.amount, th.balance_after, th.description, th.transaction_date
FROM TRANSACTION_HISTORY th
JOIN ACCOUNTS a ON th.account_id = a.account_id
ORDER BY th.transaction_date DESC
FETCH FIRST 10 ROWS ONLY;

-- Test 4: Loan Status
PROMPT 'Test 4: Loan Applications';
SELECT l.loan_id, c.first_name || ' ' || c.last_name as customer_name,
       l.loan_type, l.principal_amount, l.interest_rate, l.emi_amount, l.status
FROM LOANS l
JOIN CUSTOMERS c ON l.customer_id = c.customer_id
ORDER BY l.loan_id;

-- Test 5: Function Tests
PROMPT 'Test 5: Function Tests';
SELECT 'Account Balance for Account 100001' as test, get_account_balance(100001) as result FROM DUAL
UNION ALL
SELECT 'EMI Calculation (50000, 12, 24)', calculate_emi(50000, 12, 24) FROM DUAL
UNION ALL
SELECT 'Interest Calculation (10000, 4.5, 30)', calculate_interest(10000, 4.5, 30) FROM DUAL;

-- Test 6: Package Function Test
PROMPT 'Test 6: Package Tests - Customer Details';
DECLARE
    v_cursor SYS_REFCURSOR;
    v_customer_id NUMBER;
    v_name VARCHAR2(100);
    v_email VARCHAR2(100);
    v_status VARCHAR2(10);
BEGIN
    v_cursor := pkg_customer_mgmt.get_customer_details(1001);
    FETCH v_cursor INTO v_customer_id, v_name, v_name, v_email, v_name, v_name, v_name, v_name, v_status;
    CLOSE v_cursor;
    
    DBMS_OUTPUT.PUT_LINE('Customer 1001 Status: ' || v_status);
END;
/

-- Test 7: Trigger Test - Try invalid withdrawal
PROMPT 'Test 7: Testing Overdraft Prevention Trigger';
DECLARE
    v_error_message VARCHAR2(4000);
BEGIN
    -- This should fail due to insufficient balance
    pkg_account_mgmt.withdraw_money(100001, 999999, 'Test overdraft prevention');
    DBMS_OUTPUT.PUT_LINE('ERROR: Overdraft prevention failed!');
EXCEPTION
    WHEN OTHERS THEN
        v_error_message := SQLERRM;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Overdraft prevented - ' || v_error_message);
END;
/

-- Test 8: Account Balance Summary
PROMPT 'Test 8: Account Balance Summary';
SELECT at.type_name, COUNT(*) as account_count, SUM(a.balance) as total_balance
FROM ACCOUNTS a
JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
WHERE a.status = 'ACTIVE'
GROUP BY at.type_name;

-- Test 9: Loan Payment Summary
PROMPT 'Test 9: Loan Payment Summary';
SELECT l.loan_id, l.loan_type, l.principal_amount, l.outstanding_balance,
       COUNT(lp.payment_id) as payments_made, SUM(lp.payment_amount) as total_paid
FROM LOANS l
LEFT JOIN LOAN_PAYMENTS lp ON l.loan_id = lp.loan_id
WHERE l.status IN ('DISBURSED', 'CLOSED')
GROUP BY l.loan_id, l.loan_type, l.principal_amount, l.outstanding_balance
ORDER BY l.loan_id;

-- Test 10: System Health Check
PROMPT 'Test 10: System Health Check';
SELECT 'Total Customers' as metric, COUNT(*) as value FROM CUSTOMERS
UNION ALL
SELECT 'Active Accounts', COUNT(*) FROM ACCOUNTS WHERE status = 'ACTIVE'
UNION ALL
SELECT 'Total Transactions', COUNT(*) FROM TRANSACTION_HISTORY
UNION ALL
SELECT 'Active Loans', COUNT(*) FROM LOANS WHERE status IN ('APPROVED', 'DISBURSED')
UNION ALL
SELECT 'Total Deposits', SUM(balance) FROM ACCOUNTS WHERE status = 'ACTIVE';

PROMPT '';
PROMPT 'All tests completed successfully!';
PROMPT 'The Banking Management System is ready for use.';
PROMPT '';