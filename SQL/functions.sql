-- Banking Management System - Functions
-- Author: Shivam Dubey
-- Description: Utility functions for banking operations

-- Function to calculate EMI (Equated Monthly Installment)
CREATE OR REPLACE FUNCTION calculate_emi(
    p_principal IN NUMBER,
    p_rate IN NUMBER,
    p_tenure IN NUMBER
) RETURN NUMBER
IS
    v_monthly_rate NUMBER;
    v_emi NUMBER;
BEGIN
    -- Convert annual rate to monthly rate
    v_monthly_rate := p_rate / (12 * 100);
    
    -- EMI formula: P * r * (1+r)^n / ((1+r)^n - 1)
    IF v_monthly_rate = 0 THEN
        v_emi := p_principal / p_tenure;
    ELSE
        v_emi := p_principal * v_monthly_rate * POWER(1 + v_monthly_rate, p_tenure) / 
                 (POWER(1 + v_monthly_rate, p_tenure) - 1);
    END IF;
    
    RETURN ROUND(v_emi, 2);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error calculating EMI: ' || SQLERRM);
END calculate_emi;
/

-- Function to get account balance
CREATE OR REPLACE FUNCTION get_account_balance(
    p_account_id IN NUMBER
) RETURN NUMBER
IS
    v_balance NUMBER;
BEGIN
    SELECT balance 
    INTO v_balance 
    FROM ACCOUNTS 
    WHERE account_id = p_account_id AND status = 'ACTIVE';
    
    RETURN v_balance;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Account not found or inactive');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error retrieving balance: ' || SQLERRM);
END get_account_balance;
/

-- Function to get loan outstanding balance
CREATE OR REPLACE FUNCTION get_loan_balance(
    p_loan_id IN NUMBER
) RETURN NUMBER
IS
    v_balance NUMBER;
BEGIN
    SELECT outstanding_balance 
    INTO v_balance 
    FROM LOANS 
    WHERE loan_id = p_loan_id AND status IN ('APPROVED', 'DISBURSED');
    
    RETURN NVL(v_balance, 0);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20004, 'Loan not found or not active');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error retrieving loan balance: ' || SQLERRM);
END get_loan_balance;
/

-- Function to generate account number
CREATE OR REPLACE FUNCTION generate_account_number(
    p_account_type_id IN NUMBER
) RETURN VARCHAR2
IS
    v_account_number VARCHAR2(20);
    v_prefix VARCHAR2(3);
BEGIN
    -- Set prefix based on account type
    CASE p_account_type_id
        WHEN 1 THEN v_prefix := 'SAV'; -- Savings
        WHEN 2 THEN v_prefix := 'CUR'; -- Current
        ELSE v_prefix := 'ACC';
    END CASE;
    
    -- Generate account number: PREFIX + YYYYMMDD + SEQUENCE
    v_account_number := v_prefix || TO_CHAR(SYSDATE, 'YYYYMMDD') || 
                       LPAD(seq_account_id.NEXTVAL, 6, '0');
    
    RETURN v_account_number;
END generate_account_number;
/

-- Function to validate customer age
CREATE OR REPLACE FUNCTION validate_customer_age(
    p_date_of_birth IN DATE
) RETURN BOOLEAN
IS
    v_age NUMBER;
BEGIN
    v_age := FLOOR(MONTHS_BETWEEN(SYSDATE, p_date_of_birth) / 12);
    
    -- Customer must be at least 18 years old
    RETURN v_age >= 18;
END validate_customer_age;
/

-- Function to calculate interest for savings account
CREATE OR REPLACE FUNCTION calculate_interest(
    p_balance IN NUMBER,
    p_rate IN NUMBER,
    p_days IN NUMBER DEFAULT 30
) RETURN NUMBER
IS
    v_interest NUMBER;
BEGIN
    -- Simple interest calculation: (P * R * T) / (100 * 365)
    v_interest := (p_balance * p_rate * p_days) / (100 * 365);
    
    RETURN ROUND(v_interest, 2);
END calculate_interest;
/

-- Function to check if account can be closed
CREATE OR REPLACE FUNCTION can_close_account(
    p_account_id IN NUMBER
) RETURN BOOLEAN
IS
    v_balance NUMBER;
    v_loan_count NUMBER;
BEGIN
    -- Check account balance
    SELECT balance INTO v_balance 
    FROM ACCOUNTS 
    WHERE account_id = p_account_id;
    
    -- Check for active loans
    SELECT COUNT(*) INTO v_loan_count
    FROM LOANS l
    JOIN ACCOUNTS a ON l.customer_id = a.customer_id
    WHERE a.account_id = p_account_id 
    AND l.status IN ('APPROVED', 'DISBURSED');
    
    -- Account can be closed if balance is zero and no active loans
    RETURN (v_balance = 0 AND v_loan_count = 0);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
END can_close_account;
/

COMMIT;

PROMPT 'Banking Management System functions created successfully!'