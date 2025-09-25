-- Banking Management System - Sample Data
-- Author: BMS Development Team
-- Description: Insert sample data for testing and demonstration

-- Insert Account Types
INSERT INTO ACCOUNT_TYPES (type_id, type_name, min_balance, interest_rate) VALUES (1, 'SAVINGS', 1000, 4.5);
INSERT INTO ACCOUNT_TYPES (type_id, type_name, min_balance, interest_rate) VALUES (2, 'CURRENT', 5000, 0);

-- Insert Sample Customers
DECLARE
    v_customer_id NUMBER;
BEGIN
    -- Customer 1
    pkg_customer_mgmt.add_customer(
        'John', 'Doe', 'john.doe@email.com', '9876543210', 
        '123 Main Street, City', DATE '1985-05-15', v_customer_id
    );
    
    -- Customer 2
    pkg_customer_mgmt.add_customer(
        'Jane', 'Smith', 'jane.smith@email.com', '9876543211', 
        '456 Oak Avenue, City', DATE '1990-08-22', v_customer_id
    );
    
    -- Customer 3
    pkg_customer_mgmt.add_customer(
        'Robert', 'Johnson', 'robert.j@email.com', '9876543212', 
        '789 Pine Road, City', DATE '1982-12-10', v_customer_id
    );
    
    -- Customer 4
    pkg_customer_mgmt.add_customer(
        'Emily', 'Davis', 'emily.davis@email.com', '9876543213', 
        '321 Elm Street, City', DATE '1988-03-18', v_customer_id
    );
    
    -- Customer 5
    pkg_customer_mgmt.add_customer(
        'Michael', 'Wilson', 'michael.w@email.com', '9876543214', 
        '654 Maple Drive, City', DATE '1975-11-25', v_customer_id
    );
END;
/

-- Open Sample Accounts
DECLARE
    v_account_id NUMBER;
BEGIN
    -- Savings accounts
    pkg_account_mgmt.open_account(1001, 1, 5000, v_account_id); -- John Doe
    pkg_account_mgmt.open_account(1002, 1, 3000, v_account_id); -- Jane Smith
    pkg_account_mgmt.open_account(1003, 1, 10000, v_account_id); -- Robert Johnson
    pkg_account_mgmt.open_account(1004, 1, 2500, v_account_id); -- Emily Davis
    
    -- Current accounts
    pkg_account_mgmt.open_account(1001, 2, 15000, v_account_id); -- John Doe
    pkg_account_mgmt.open_account(1005, 2, 25000, v_account_id); -- Michael Wilson
END;
/

-- Sample Transactions
BEGIN
    -- Deposits
    pkg_account_mgmt.deposit_money(100001, 2000, 'Salary deposit');
    pkg_account_mgmt.deposit_money(100002, 1500, 'Cash deposit');
    pkg_account_mgmt.deposit_money(100003, 5000, 'Business income');
    
    -- Withdrawals
    pkg_account_mgmt.withdraw_money(100001, 1000, 'ATM withdrawal');
    pkg_account_mgmt.withdraw_money(100003, 2000, 'Cash withdrawal');
    
    -- Fund transfers
    pkg_account_mgmt.transfer_funds(100001, 100002, 500, 'Payment to Jane');
    pkg_account_mgmt.transfer_funds(100003, 100004, 1000, 'Family transfer');
END;
/

-- Sample Loan Applications
DECLARE
    v_loan_id NUMBER;
BEGIN
    -- Personal loans
    pkg_loan_mgmt.apply_loan(1001, 'PERSONAL', 50000, 12.5, 24, v_loan_id);
    pkg_loan_mgmt.apply_loan(1002, 'PERSONAL', 30000, 11.0, 18, v_loan_id);
    
    -- Home loans
    pkg_loan_mgmt.apply_loan(1003, 'HOME', 500000, 8.5, 240, v_loan_id);
    pkg_loan_mgmt.apply_loan(1004, 'HOME', 750000, 8.0, 300, v_loan_id);
    
    -- Car loan
    pkg_loan_mgmt.apply_loan(1005, 'CAR', 200000, 10.0, 60, v_loan_id);
END;
/

-- Process some loan applications
BEGIN
    -- Approve some loans
    pkg_loan_mgmt.process_loan_application(10001, 'APPROVE', 'Good credit history');
    pkg_loan_mgmt.process_loan_application(10002, 'APPROVE', 'Stable income verified');
    pkg_loan_mgmt.process_loan_application(10003, 'APPROVE', 'Property documents verified');
    
    -- Reject one loan
    pkg_loan_mgmt.process_loan_application(10004, 'REJECT', 'Insufficient income');
    
    -- Keep one pending
    -- Loan 10005 remains in PENDING status
END;
/

-- Disburse approved loans
BEGIN
    pkg_loan_mgmt.disburse_loan(10001, 100001); -- Personal loan to John's savings
    pkg_loan_mgmt.disburse_loan(10002, 100002); -- Personal loan to Jane's savings
    pkg_loan_mgmt.disburse_loan(10003, 100003); -- Home loan to Robert's savings
END;
/

-- Sample loan payments
BEGIN
    pkg_loan_mgmt.make_loan_payment(10001, 2347.50); -- EMI payment
    pkg_loan_mgmt.make_loan_payment(10001, 2347.50); -- Second EMI
    pkg_loan_mgmt.make_loan_payment(10002, 1806.50); -- EMI payment
    pkg_loan_mgmt.make_loan_payment(10003, 4240.50); -- Home loan EMI
END;
/

-- Add some historical transactions (backdated for reporting)
INSERT INTO TRANSACTION_HISTORY (
    transaction_id, account_id, transaction_type, amount, balance_after, 
    description, transaction_date
) VALUES (
    seq_transaction_id.NEXTVAL, 100001, 'DEPOSIT', 1000, 7000,
    'Monthly salary - Previous month', SYSDATE - 30
);

INSERT INTO TRANSACTION_HISTORY (
    transaction_id, account_id, transaction_type, amount, balance_after, 
    description, transaction_date
) VALUES (
    seq_transaction_id.NEXTVAL, 100002, 'WITHDRAWAL', 500, 4000,
    'Grocery shopping', SYSDATE - 15
);

INSERT INTO TRANSACTION_HISTORY (
    transaction_id, account_id, transaction_type, amount, balance_after, 
    description, transaction_date
) VALUES (
    seq_transaction_id.NEXTVAL, 100003, 'DEPOSIT', 3000, 16000,
    'Business payment received', SYSDATE - 7
);

COMMIT;

-- Display summary of sample data
SELECT 'CUSTOMERS' as TABLE_NAME, COUNT(*) as RECORD_COUNT FROM CUSTOMERS
UNION ALL
SELECT 'ACCOUNTS', COUNT(*) FROM ACCOUNTS
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM TRANSACTION_HISTORY
UNION ALL
SELECT 'LOANS', COUNT(*) FROM LOANS
UNION ALL
SELECT 'LOAN_PAYMENTS', COUNT(*) FROM LOAN_PAYMENTS;

PROMPT 'Sample data inserted successfully!';
PROMPT 'Summary:';
PROMPT '- 5 Customers created';
PROMPT '- 6 Accounts opened (4 Savings, 2 Current)';
PROMPT '- Multiple transactions processed';
PROMPT '- 5 Loan applications (3 approved and disbursed, 1 rejected, 1 pending)';
PROMPT '- Sample loan payments made';
PROMPT '';
PROMPT 'You can now test the system with the sample data!';