-- Banking Management System - Triggers
-- Author: BMS Development Team
-- Description: Database triggers for business rules and audit trails

-- Trigger to prevent overdraft (additional safety check)
CREATE OR REPLACE TRIGGER trg_prevent_overdraft
    BEFORE UPDATE OF balance ON ACCOUNTS
    FOR EACH ROW
DECLARE
    v_min_balance NUMBER;
BEGIN
    -- Get minimum balance for account type
    SELECT min_balance INTO v_min_balance
    FROM ACCOUNT_TYPES
    WHERE type_id = :NEW.account_type_id;
    
    -- Check if new balance violates minimum balance
    IF :NEW.balance < v_min_balance THEN
        RAISE_APPLICATION_ERROR(-20100, 
            'Transaction would violate minimum balance requirement of ' || v_min_balance);
    END IF;
END;
/

-- Trigger to update customer updated_date
CREATE OR REPLACE TRIGGER trg_customer_update_date
    BEFORE UPDATE ON CUSTOMERS
    FOR EACH ROW
BEGIN
    :NEW.updated_date := SYSDATE;
END;
/

-- Trigger to auto-update loan status when fully paid
CREATE OR REPLACE TRIGGER trg_loan_status_update
    AFTER INSERT ON LOAN_PAYMENTS
    FOR EACH ROW
DECLARE
    v_outstanding_balance NUMBER;
    v_loan_status VARCHAR2(15);
BEGIN
    -- Get current loan status and outstanding balance
    SELECT outstanding_balance, status 
    INTO v_outstanding_balance, v_loan_status
    FROM LOANS 
    WHERE loan_id = :NEW.loan_id;
    
    -- Update outstanding balance
    UPDATE LOANS 
    SET outstanding_balance = outstanding_balance - :NEW.principal_component
    WHERE loan_id = :NEW.loan_id;
    
    -- Check if loan is fully paid
    IF (v_outstanding_balance - :NEW.principal_component) <= 0 AND v_loan_status = 'DISBURSED' THEN
        UPDATE LOANS 
        SET status = 'CLOSED',
            outstanding_balance = 0
        WHERE loan_id = :NEW.loan_id;
        
        -- Log status change in audit
        INSERT INTO LOAN_AUDIT (
            audit_id, loan_id, old_status, new_status, 
            changed_by, change_date, remarks
        ) VALUES (
            seq_audit_id.NEXTVAL, :NEW.loan_id, 'DISBURSED', 'CLOSED',
            'SYSTEM', SYSDATE, 'Loan fully paid - auto closed'
        );
    END IF;
END;
/

-- Trigger to validate transaction amounts
CREATE OR REPLACE TRIGGER trg_validate_transaction
    BEFORE INSERT ON TRANSACTION_HISTORY
    FOR EACH ROW
BEGIN
    -- Ensure transaction amount is positive
    IF :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20110, 'Transaction amount must be positive');
    END IF;
    
    -- Ensure balance after transaction is not negative
    IF :NEW.balance_after < 0 THEN
        RAISE_APPLICATION_ERROR(-20111, 'Transaction would result in negative balance');
    END IF;
    
    -- Set transaction date if not provided
    IF :NEW.transaction_date IS NULL THEN
        :NEW.transaction_date := SYSDATE;
    END IF;
END;
/

-- Trigger to log loan status changes
CREATE OR REPLACE TRIGGER trg_loan_audit_log
    AFTER UPDATE OF status ON LOANS
    FOR EACH ROW
    WHEN (OLD.status != NEW.status)
BEGIN
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status, 
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, :NEW.loan_id, :OLD.status, :NEW.status,
        USER, SYSDATE, 'Status changed via trigger'
    );
END;
/

-- Trigger to validate account closure
CREATE OR REPLACE TRIGGER trg_validate_account_closure
    BEFORE UPDATE OF status ON ACCOUNTS
    FOR EACH ROW
    WHEN (OLD.status = 'ACTIVE' AND NEW.status = 'CLOSED')
DECLARE
    v_loan_count NUMBER;
BEGIN
    -- Check if customer has active loans
    SELECT COUNT(*) INTO v_loan_count
    FROM LOANS 
    WHERE customer_id = :NEW.customer_id 
    AND status IN ('APPROVED', 'DISBURSED');
    
    IF v_loan_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20120, 
            'Cannot close account. Customer has active loans');
    END IF;
    
    -- Check if account has balance
    IF :NEW.balance != 0 THEN
        RAISE_APPLICATION_ERROR(-20121, 
            'Cannot close account with non-zero balance');
    END IF;
    
    -- Set closure date
    :NEW.closed_date := SYSDATE;
END;
/

-- Trigger to validate loan disbursement
CREATE OR REPLACE TRIGGER trg_validate_loan_disbursement
    BEFORE UPDATE OF status ON LOANS
    FOR EACH ROW
    WHEN (OLD.status = 'APPROVED' AND NEW.status = 'DISBURSED')
BEGIN
    -- Set disbursement date
    :NEW.disbursement_date := SYSDATE;
    
    -- Ensure outstanding balance is set to principal amount
    IF :NEW.outstanding_balance IS NULL OR :NEW.outstanding_balance = 0 THEN
        :NEW.outstanding_balance := :NEW.principal_amount;
    END IF;
END;
/

-- Trigger to prevent deletion of accounts with transaction history
CREATE OR REPLACE TRIGGER trg_prevent_account_deletion
    BEFORE DELETE ON ACCOUNTS
    FOR EACH ROW
DECLARE
    v_transaction_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_transaction_count
    FROM TRANSACTION_HISTORY
    WHERE account_id = :OLD.account_id;
    
    IF v_transaction_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20130, 
            'Cannot delete account with transaction history. Mark as closed instead.');
    END IF;
END;
/

-- Trigger to prevent deletion of customers with accounts or loans
CREATE OR REPLACE TRIGGER trg_prevent_customer_deletion
    BEFORE DELETE ON CUSTOMERS
    FOR EACH ROW
DECLARE
    v_account_count NUMBER;
    v_loan_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_account_count
    FROM ACCOUNTS
    WHERE customer_id = :OLD.customer_id;
    
    SELECT COUNT(*) INTO v_loan_count
    FROM LOANS
    WHERE customer_id = :OLD.customer_id;
    
    IF v_account_count > 0 OR v_loan_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20140, 
            'Cannot delete customer with existing accounts or loans. Mark as inactive instead.');
    END IF;
END;
/

-- Trigger to automatically calculate interest components in loan payments
CREATE OR REPLACE TRIGGER trg_calculate_payment_components
    BEFORE INSERT ON LOAN_PAYMENTS
    FOR EACH ROW
DECLARE
    v_outstanding_balance NUMBER;
    v_interest_rate NUMBER;
    v_monthly_rate NUMBER;
    v_interest_component NUMBER;
BEGIN
    -- Get loan details
    SELECT outstanding_balance, interest_rate
    INTO v_outstanding_balance, v_interest_rate
    FROM LOANS
    WHERE loan_id = :NEW.loan_id;
    
    -- Calculate monthly interest rate
    v_monthly_rate := v_interest_rate / (12 * 100);
    
    -- Calculate interest component (simple interest for the month)
    v_interest_component := v_outstanding_balance * v_monthly_rate;
    
    -- Set components
    :NEW.interest_component := ROUND(v_interest_component, 2);
    :NEW.principal_component := :NEW.payment_amount - :NEW.interest_component;
    
    -- Ensure principal component is not negative
    IF :NEW.principal_component < 0 THEN
        :NEW.principal_component := 0;
        :NEW.interest_component := :NEW.payment_amount;
    END IF;
    
    -- Set outstanding balance after payment
    :NEW.outstanding_after_payment := v_outstanding_balance - :NEW.principal_component;
END;
/

COMMIT;

PROMPT 'Banking Management System triggers created successfully!'