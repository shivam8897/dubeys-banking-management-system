-- Banking Management System - Packages
-- Author: BMS Development Team
-- Description: Organized packages for modular functionality

-- Package for Customer Management Operations
CREATE OR REPLACE PACKAGE pkg_customer_mgmt AS
    -- Public procedures and functions
    PROCEDURE add_customer(
        p_first_name IN VARCHAR2,
        p_last_name IN VARCHAR2,
        p_email IN VARCHAR2,
        p_phone IN VARCHAR2,
        p_address IN VARCHAR2,
        p_date_of_birth IN DATE,
        p_customer_id OUT NUMBER
    );
    
    PROCEDURE update_customer(
        p_customer_id IN NUMBER,
        p_first_name IN VARCHAR2 DEFAULT NULL,
        p_last_name IN VARCHAR2 DEFAULT NULL,
        p_email IN VARCHAR2 DEFAULT NULL,
        p_phone IN VARCHAR2 DEFAULT NULL,
        p_address IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE deactivate_customer(
        p_customer_id IN NUMBER
    );
    
    FUNCTION get_customer_details(
        p_customer_id IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION get_customer_accounts(
        p_customer_id IN NUMBER
    ) RETURN SYS_REFCURSOR;
END pkg_customer_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_customer_mgmt AS
    
    PROCEDURE add_customer(
        p_first_name IN VARCHAR2,
        p_last_name IN VARCHAR2,
        p_email IN VARCHAR2,
        p_phone IN VARCHAR2,
        p_address IN VARCHAR2,
        p_date_of_birth IN DATE,
        p_customer_id OUT NUMBER
    ) IS
    BEGIN
        add_customer(p_first_name, p_last_name, p_email, p_phone, p_address, p_date_of_birth, p_customer_id);
    END add_customer;
    
    PROCEDURE update_customer(
        p_customer_id IN NUMBER,
        p_first_name IN VARCHAR2 DEFAULT NULL,
        p_last_name IN VARCHAR2 DEFAULT NULL,
        p_email IN VARCHAR2 DEFAULT NULL,
        p_phone IN VARCHAR2 DEFAULT NULL,
        p_address IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE CUSTOMERS 
        SET first_name = NVL(p_first_name, first_name),
            last_name = NVL(p_last_name, last_name),
            email = NVL(p_email, email),
            phone = NVL(p_phone, phone),
            address = NVL(p_address, address),
            updated_date = SYSDATE
        WHERE customer_id = p_customer_id AND status = 'ACTIVE';
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20200, 'Customer not found or inactive');
        END IF;
        
        COMMIT;
    END update_customer;
    
    PROCEDURE deactivate_customer(
        p_customer_id IN NUMBER
    ) IS
        v_account_count NUMBER;
        v_loan_count NUMBER;
    BEGIN
        -- Check for active accounts
        SELECT COUNT(*) INTO v_account_count
        FROM ACCOUNTS
        WHERE customer_id = p_customer_id AND status = 'ACTIVE';
        
        -- Check for active loans
        SELECT COUNT(*) INTO v_loan_count
        FROM LOANS
        WHERE customer_id = p_customer_id AND status IN ('APPROVED', 'DISBURSED');
        
        IF v_account_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20201, 'Cannot deactivate customer with active accounts');
        END IF;
        
        IF v_loan_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20202, 'Cannot deactivate customer with active loans');
        END IF;
        
        UPDATE CUSTOMERS 
        SET status = 'INACTIVE',
            updated_date = SYSDATE
        WHERE customer_id = p_customer_id;
        
        COMMIT;
    END deactivate_customer;
    
    FUNCTION get_customer_details(
        p_customer_id IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT customer_id, first_name, last_name, email, phone, 
                   address, date_of_birth, created_date, status
            FROM CUSTOMERS
            WHERE customer_id = p_customer_id;
        
        RETURN v_cursor;
    END get_customer_details;
    
    FUNCTION get_customer_accounts(
        p_customer_id IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT a.account_id, a.account_number, at.type_name, 
                   a.balance, a.opened_date, a.status
            FROM ACCOUNTS a
            JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
            WHERE a.customer_id = p_customer_id
            ORDER BY a.opened_date DESC;
        
        RETURN v_cursor;
    END get_customer_accounts;
    
END pkg_customer_mgmt;
/

-- Package for Account Management Operations
CREATE OR REPLACE PACKAGE pkg_account_mgmt AS
    
    PROCEDURE open_account(
        p_customer_id IN NUMBER,
        p_account_type_id IN NUMBER,
        p_initial_deposit IN NUMBER DEFAULT 0,
        p_account_id OUT NUMBER
    );
    
    PROCEDURE close_account(
        p_account_id IN NUMBER
    );
    
    PROCEDURE deposit_money(
        p_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Cash deposit'
    );
    
    PROCEDURE withdraw_money(
        p_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Cash withdrawal'
    );
    
    PROCEDURE transfer_funds(
        p_from_account_id IN NUMBER,
        p_to_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Fund transfer'
    );
    
    FUNCTION get_account_statement(
        p_account_id IN NUMBER,
        p_from_date IN DATE DEFAULT SYSDATE - 30,
        p_to_date IN DATE DEFAULT SYSDATE
    ) RETURN SYS_REFCURSOR;
    
END pkg_account_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_account_mgmt AS
    
    PROCEDURE open_account(
        p_customer_id IN NUMBER,
        p_account_type_id IN NUMBER,
        p_initial_deposit IN NUMBER DEFAULT 0,
        p_account_id OUT NUMBER
    ) IS
    BEGIN
        open_account(p_customer_id, p_account_type_id, p_initial_deposit, p_account_id);
    END open_account;
    
    PROCEDURE close_account(
        p_account_id IN NUMBER
    ) IS
    BEGIN
        IF NOT can_close_account(p_account_id) THEN
            RAISE_APPLICATION_ERROR(-20210, 'Account cannot be closed. Check balance and loans.');
        END IF;
        
        UPDATE ACCOUNTS 
        SET status = 'CLOSED',
            closed_date = SYSDATE
        WHERE account_id = p_account_id;
        
        COMMIT;
    END close_account;
    
    PROCEDURE deposit_money(
        p_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Cash deposit'
    ) IS
    BEGIN
        deposit_money(p_account_id, p_amount, p_description);
    END deposit_money;
    
    PROCEDURE withdraw_money(
        p_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Cash withdrawal'
    ) IS
    BEGIN
        withdraw_money(p_account_id, p_amount, p_description);
    END withdraw_money;
    
    PROCEDURE transfer_funds(
        p_from_account_id IN NUMBER,
        p_to_account_id IN NUMBER,
        p_amount IN NUMBER,
        p_description IN VARCHAR2 DEFAULT 'Fund transfer'
    ) IS
    BEGIN
        transfer_funds(p_from_account_id, p_to_account_id, p_amount, p_description);
    END transfer_funds;
    
    FUNCTION get_account_statement(
        p_account_id IN NUMBER,
        p_from_date IN DATE DEFAULT SYSDATE - 30,
        p_to_date IN DATE DEFAULT SYSDATE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT transaction_id, transaction_type, amount, balance_after,
                   description, transaction_date, reference_account_id
            FROM TRANSACTION_HISTORY
            WHERE account_id = p_account_id
            AND transaction_date BETWEEN p_from_date AND p_to_date + 1
            ORDER BY transaction_date DESC, transaction_id DESC;
        
        RETURN v_cursor;
    END get_account_statement;
    
END pkg_account_mgmt;
/

-- Package for Loan Management Operations
CREATE OR REPLACE PACKAGE pkg_loan_mgmt AS
    
    PROCEDURE apply_loan(
        p_customer_id IN NUMBER,
        p_loan_type IN VARCHAR2,
        p_principal_amount IN NUMBER,
        p_interest_rate IN NUMBER,
        p_tenure_months IN NUMBER,
        p_loan_id OUT NUMBER
    );
    
    PROCEDURE process_loan_application(
        p_loan_id IN NUMBER,
        p_action IN VARCHAR2,
        p_remarks IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE disburse_loan(
        p_loan_id IN NUMBER,
        p_account_id IN NUMBER
    );
    
    PROCEDURE make_loan_payment(
        p_loan_id IN NUMBER,
        p_payment_amount IN NUMBER
    );
    
    FUNCTION get_loan_schedule(
        p_loan_id IN NUMBER
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION get_overdue_loans RETURN SYS_REFCURSOR;
    
END pkg_loan_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_loan_mgmt AS
    
    PROCEDURE apply_loan(
        p_customer_id IN NUMBER,
        p_loan_type IN VARCHAR2,
        p_principal_amount IN NUMBER,
        p_interest_rate IN NUMBER,
        p_tenure_months IN NUMBER,
        p_loan_id OUT NUMBER
    ) IS
    BEGIN
        apply_loan(p_customer_id, p_loan_type, p_principal_amount, p_interest_rate, p_tenure_months, p_loan_id);
    END apply_loan;
    
    PROCEDURE process_loan_application(
        p_loan_id IN NUMBER,
        p_action IN VARCHAR2,
        p_remarks IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        process_loan_application(p_loan_id, p_action, p_remarks);
    END process_loan_application;
    
    PROCEDURE disburse_loan(
        p_loan_id IN NUMBER,
        p_account_id IN NUMBER
    ) IS
        v_principal_amount NUMBER;
        v_loan_status VARCHAR2(15);
    BEGIN
        -- Get loan details
        SELECT principal_amount, status
        INTO v_principal_amount, v_loan_status
        FROM LOANS
        WHERE loan_id = p_loan_id;
        
        IF v_loan_status != 'APPROVED' THEN
            RAISE_APPLICATION_ERROR(-20220, 'Loan is not approved for disbursement');
        END IF;
        
        -- Credit amount to account
        pkg_account_mgmt.deposit_money(p_account_id, v_principal_amount, 'Loan disbursement - Loan ID: ' || p_loan_id);
        
        -- Update loan status
        UPDATE LOANS
        SET status = 'DISBURSED',
            disbursement_date = SYSDATE
        WHERE loan_id = p_loan_id;
        
        COMMIT;
    END disburse_loan;
    
    PROCEDURE make_loan_payment(
        p_loan_id IN NUMBER,
        p_payment_amount IN NUMBER
    ) IS
    BEGIN
        INSERT INTO LOAN_PAYMENTS (
            payment_id, loan_id, payment_amount, payment_date
        ) VALUES (
            seq_payment_id.NEXTVAL, p_loan_id, p_payment_amount, SYSDATE
        );
        
        COMMIT;
    END make_loan_payment;
    
    FUNCTION get_loan_schedule(
        p_loan_id IN NUMBER
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT payment_id, payment_amount, payment_date,
                   principal_component, interest_component, outstanding_after_payment
            FROM LOAN_PAYMENTS
            WHERE loan_id = p_loan_id
            ORDER BY payment_date DESC;
        
        RETURN v_cursor;
    END get_loan_schedule;
    
    FUNCTION get_overdue_loans RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT l.loan_id, l.customer_id, c.first_name || ' ' || c.last_name as customer_name,
                   l.loan_type, l.outstanding_balance, l.emi_amount,
                   MONTHS_BETWEEN(SYSDATE, l.disbursement_date) as months_since_disbursement
            FROM LOANS l
            JOIN CUSTOMERS c ON l.customer_id = c.customer_id
            WHERE l.status = 'DISBURSED'
            AND l.outstanding_balance > 0
            AND MONTHS_BETWEEN(SYSDATE, l.disbursement_date) > l.tenure_months;
        
        RETURN v_cursor;
    END get_overdue_loans;
    
END pkg_loan_mgmt;
/

COMMIT;

PROMPT 'Banking Management System packages created successfully!'