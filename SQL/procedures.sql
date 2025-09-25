-- Banking Management System - Stored Procedures
-- Author: Shivam Dubey
-- Description: Core business logic procedures

-- Procedure to add a new customer
CREATE OR REPLACE PROCEDURE add_customer(
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_email IN VARCHAR2,
    p_phone IN VARCHAR2,
    p_address IN VARCHAR2,
    p_date_of_birth IN DATE,
    p_customer_id OUT NUMBER
)
IS
BEGIN
    -- Validate age
    IF NOT validate_customer_age(p_date_of_birth) THEN
        RAISE_APPLICATION_ERROR(-20010, 'Customer must be at least 18 years old');
    END IF;
    
    -- Insert new customer
    INSERT INTO CUSTOMERS (
        customer_id, first_name, last_name, email, phone, 
        address, date_of_birth, created_date, status
    ) VALUES (
        seq_customer_id.NEXTVAL, p_first_name, p_last_name, p_email, p_phone,
        p_address, p_date_of_birth, SYSDATE, 'ACTIVE'
    ) RETURNING customer_id INTO p_customer_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Customer created successfully with ID: ' || p_customer_id);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20011, 'Email already exists');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20012, 'Error creating customer: ' || SQLERRM);
END add_customer;
/

-- Procedure to open a new account
CREATE OR REPLACE PROCEDURE open_account(
    p_customer_id IN NUMBER,
    p_account_type_id IN NUMBER,
    p_initial_deposit IN NUMBER DEFAULT 0,
    p_account_id OUT NUMBER
)
IS
    v_account_number VARCHAR2(20);
    v_min_balance NUMBER;
BEGIN
    -- Check if customer exists
    DECLARE
        v_customer_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_customer_count 
        FROM CUSTOMERS 
        WHERE customer_id = p_customer_id AND status = 'ACTIVE';
        
        IF v_customer_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Customer not found or inactive');
        END IF;
    END;
    
    -- Get minimum balance requirement
    SELECT min_balance INTO v_min_balance 
    FROM ACCOUNT_TYPES 
    WHERE type_id = p_account_type_id;
    
    -- Validate initial deposit
    IF p_initial_deposit < v_min_balance THEN
        RAISE_APPLICATION_ERROR(-20021, 'Initial deposit must be at least ' || v_min_balance);
    END IF;
    
    -- Generate account number
    v_account_number := generate_account_number(p_account_type_id);
    
    -- Create account
    INSERT INTO ACCOUNTS (
        account_id, customer_id, account_type_id, balance, 
        account_number, opened_date, status
    ) VALUES (
        seq_account_id.NEXTVAL, p_customer_id, p_account_type_id, p_initial_deposit,
        v_account_number, SYSDATE, 'ACTIVE'
    ) RETURNING account_id INTO p_account_id;
    
    -- Log initial deposit transaction if amount > 0
    IF p_initial_deposit > 0 THEN
        INSERT INTO TRANSACTION_HISTORY (
            transaction_id, account_id, transaction_type, amount, 
            balance_after, description, transaction_date
        ) VALUES (
            seq_transaction_id.NEXTVAL, p_account_id, 'DEPOSIT', p_initial_deposit,
            p_initial_deposit, 'Initial deposit', SYSDATE
        );
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Account opened successfully. Account ID: ' || p_account_id || 
                        ', Account Number: ' || v_account_number);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20022, 'Error opening account: ' || SQLERRM);
END open_account;
/

-- Procedure for deposit money
CREATE OR REPLACE PROCEDURE deposit_money(
    p_account_id IN NUMBER,
    p_amount IN NUMBER,
    p_description IN VARCHAR2 DEFAULT 'Cash deposit'
)
IS
    v_new_balance NUMBER;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'Deposit amount must be positive');
    END IF;
    
    -- Update account balance
    UPDATE ACCOUNTS 
    SET balance = balance + p_amount,
        updated_date = SYSDATE
    WHERE account_id = p_account_id AND status = 'ACTIVE'
    RETURNING balance INTO v_new_balance;
    
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20031, 'Account not found or inactive');
    END IF;
    
    -- Log transaction
    INSERT INTO TRANSACTION_HISTORY (
        transaction_id, account_id, transaction_type, amount, 
        balance_after, description, transaction_date
    ) VALUES (
        seq_transaction_id.NEXTVAL, p_account_id, 'DEPOSIT', p_amount,
        v_new_balance, p_description, SYSDATE
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Deposit successful. New balance: ' || v_new_balance);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20032, 'Error processing deposit: ' || SQLERRM);
END deposit_money;
/

-- Procedure for withdraw money
CREATE OR REPLACE PROCEDURE withdraw_money(
    p_account_id IN NUMBER,
    p_amount IN NUMBER,
    p_description IN VARCHAR2 DEFAULT 'Cash withdrawal'
)
IS
    v_current_balance NUMBER;
    v_new_balance NUMBER;
    v_min_balance NUMBER;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20040, 'Withdrawal amount must be positive');
    END IF;
    
    -- Get current balance and minimum balance requirement
    SELECT a.balance, at.min_balance 
    INTO v_current_balance, v_min_balance
    FROM ACCOUNTS a
    JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
    WHERE a.account_id = p_account_id AND a.status = 'ACTIVE';
    
    -- Check if sufficient balance
    v_new_balance := v_current_balance - p_amount;
    IF v_new_balance < v_min_balance THEN
        RAISE_APPLICATION_ERROR(-20041, 'Insufficient balance. Minimum balance required: ' || v_min_balance);
    END IF;
    
    -- Update account balance
    UPDATE ACCOUNTS 
    SET balance = v_new_balance,
        updated_date = SYSDATE
    WHERE account_id = p_account_id;
    
    -- Log transaction
    INSERT INTO TRANSACTION_HISTORY (
        transaction_id, account_id, transaction_type, amount, 
        balance_after, description, transaction_date
    ) VALUES (
        seq_transaction_id.NEXTVAL, p_account_id, 'WITHDRAWAL', p_amount,
        v_new_balance, p_description, SYSDATE
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Withdrawal successful. New balance: ' || v_new_balance);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20042, 'Account not found or inactive');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20043, 'Error processing withdrawal: ' || SQLERRM);
END withdraw_money;
/

-- Procedure for fund transfer
CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_account_id IN NUMBER,
    p_to_account_id IN NUMBER,
    p_amount IN NUMBER,
    p_description IN VARCHAR2 DEFAULT 'Fund transfer'
)
IS
    v_from_balance NUMBER;
    v_to_balance NUMBER;
    v_min_balance NUMBER;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20050, 'Transfer amount must be positive');
    END IF;
    
    -- Validate accounts are different
    IF p_from_account_id = p_to_account_id THEN
        RAISE_APPLICATION_ERROR(-20051, 'Cannot transfer to the same account');
    END IF;
    
    -- Check source account balance
    SELECT a.balance, at.min_balance 
    INTO v_from_balance, v_min_balance
    FROM ACCOUNTS a
    JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
    WHERE a.account_id = p_from_account_id AND a.status = 'ACTIVE';
    
    -- Check if sufficient balance
    IF (v_from_balance - p_amount) < v_min_balance THEN
        RAISE_APPLICATION_ERROR(-20052, 'Insufficient balance for transfer');
    END IF;
    
    -- Check destination account exists
    SELECT balance INTO v_to_balance 
    FROM ACCOUNTS 
    WHERE account_id = p_to_account_id AND status = 'ACTIVE';
    
    -- Perform transfer (debit from source)
    UPDATE ACCOUNTS 
    SET balance = balance - p_amount,
        updated_date = SYSDATE
    WHERE account_id = p_from_account_id;
    
    -- Credit to destination
    UPDATE ACCOUNTS 
    SET balance = balance + p_amount,
        updated_date = SYSDATE
    WHERE account_id = p_to_account_id;
    
    -- Log debit transaction
    INSERT INTO TRANSACTION_HISTORY (
        transaction_id, account_id, transaction_type, amount, 
        balance_after, description, transaction_date, reference_account_id
    ) VALUES (
        seq_transaction_id.NEXTVAL, p_from_account_id, 'TRANSFER_OUT', p_amount,
        v_from_balance - p_amount, p_description, SYSDATE, p_to_account_id
    );
    
    -- Log credit transaction
    INSERT INTO TRANSACTION_HISTORY (
        transaction_id, account_id, transaction_type, amount, 
        balance_after, description, transaction_date, reference_account_id
    ) VALUES (
        seq_transaction_id.NEXTVAL, p_to_account_id, 'TRANSFER_IN', p_amount,
        v_to_balance + p_amount, p_description, SYSDATE, p_from_account_id
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Transfer successful. Amount: ' || p_amount);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20053, 'One or both accounts not found or inactive');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20054, 'Error processing transfer: ' || SQLERRM);
END transfer_funds;
/

-- Procedure to apply for loan
CREATE OR REPLACE PROCEDURE apply_loan(
    p_customer_id IN NUMBER,
    p_loan_type IN VARCHAR2,
    p_principal_amount IN NUMBER,
    p_interest_rate IN NUMBER,
    p_tenure_months IN NUMBER,
    p_loan_id OUT NUMBER
)
IS
    v_emi_amount NUMBER;
BEGIN
    -- Validate customer exists
    DECLARE
        v_customer_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_customer_count 
        FROM CUSTOMERS 
        WHERE customer_id = p_customer_id AND status = 'ACTIVE';
        
        IF v_customer_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20060, 'Customer not found or inactive');
        END IF;
    END;
    
    -- Calculate EMI
    v_emi_amount := calculate_emi(p_principal_amount, p_interest_rate, p_tenure_months);
    
    -- Create loan application
    INSERT INTO LOANS (
        loan_id, customer_id, loan_type, principal_amount, interest_rate,
        tenure_months, emi_amount, outstanding_balance, application_date, status
    ) VALUES (
        seq_loan_id.NEXTVAL, p_customer_id, p_loan_type, p_principal_amount, p_interest_rate,
        p_tenure_months, v_emi_amount, p_principal_amount, SYSDATE, 'PENDING'
    ) RETURNING loan_id INTO p_loan_id;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Loan application submitted. Loan ID: ' || p_loan_id || 
                        ', EMI Amount: ' || v_emi_amount);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20061, 'Error applying for loan: ' || SQLERRM);
END apply_loan;
/

-- Procedure to approve/reject loan
CREATE OR REPLACE PROCEDURE process_loan_application(
    p_loan_id IN NUMBER,
    p_action IN VARCHAR2, -- 'APPROVE' or 'REJECT'
    p_remarks IN VARCHAR2 DEFAULT NULL
)
IS
    v_old_status VARCHAR2(15);
    v_new_status VARCHAR2(15);
BEGIN
    -- Get current status
    SELECT status INTO v_old_status 
    FROM LOANS 
    WHERE loan_id = p_loan_id;
    
    -- Validate current status
    IF v_old_status != 'PENDING' THEN
        RAISE_APPLICATION_ERROR(-20070, 'Loan is not in pending status');
    END IF;
    
    -- Set new status
    v_new_status := CASE UPPER(p_action)
                       WHEN 'APPROVE' THEN 'APPROVED'
                       WHEN 'REJECT' THEN 'REJECTED'
                       ELSE NULL
                   END;
    
    IF v_new_status IS NULL THEN
        RAISE_APPLICATION_ERROR(-20071, 'Invalid action. Use APPROVE or REJECT');
    END IF;
    
    -- Update loan status
    UPDATE LOANS 
    SET status = v_new_status,
        approval_date = CASE WHEN v_new_status = 'APPROVED' THEN SYSDATE ELSE NULL END
    WHERE loan_id = p_loan_id;
    
    -- Log audit trail
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status, 
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, p_loan_id, v_old_status, v_new_status,
        USER, SYSDATE, p_remarks
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Loan ' || p_action || 'D successfully');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20072, 'Loan not found');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20073, 'Error processing loan: ' || SQLERRM);
END process_loan_application;
/

COMMIT;

PROMPT 'Banking Management System procedures created successfully!'