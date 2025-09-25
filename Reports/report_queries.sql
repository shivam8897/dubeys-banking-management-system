-- Banking Management System - Report Queries
-- Author: BMS Development Team
-- Description: Comprehensive reporting queries for business intelligence

-- 1. Customer Account Summary Report
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.phone,
    COUNT(a.account_id) AS total_accounts,
    SUM(CASE WHEN a.status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_accounts,
    SUM(CASE WHEN a.status = 'ACTIVE' THEN a.balance ELSE 0 END) AS total_balance,
    c.created_date AS customer_since
FROM CUSTOMERS c
LEFT JOIN ACCOUNTS a ON c.customer_id = a.customer_id
WHERE c.status = 'ACTIVE'
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, c.phone, c.created_date
ORDER BY total_balance DESC;

-- 2. Monthly Transaction Report
SELECT 
    TO_CHAR(th.transaction_date, 'YYYY-MM') AS month_year,
    th.transaction_type,
    COUNT(*) AS transaction_count,
    SUM(th.amount) AS total_amount,
    AVG(th.amount) AS average_amount,
    MIN(th.amount) AS min_amount,
    MAX(th.amount) AS max_amount
FROM TRANSACTION_HISTORY th
WHERE th.transaction_date >= ADD_MONTHS(SYSDATE, -12)
GROUP BY TO_CHAR(th.transaction_date, 'YYYY-MM'), th.transaction_type
ORDER BY month_year DESC, th.transaction_type;

-- 3. Account Balance Summary by Type
SELECT 
    at.type_name AS account_type,
    COUNT(a.account_id) AS total_accounts,
    SUM(a.balance) AS total_balance,
    AVG(a.balance) AS average_balance,
    MIN(a.balance) AS minimum_balance,
    MAX(a.balance) AS maximum_balance,
    at.min_balance AS required_min_balance
FROM ACCOUNTS a
JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
WHERE a.status = 'ACTIVE'
GROUP BY at.type_name, at.min_balance
ORDER BY total_balance DESC;

-- 4. Loan Portfolio Summary
SELECT 
    l.loan_type,
    l.status,
    COUNT(*) AS loan_count,
    SUM(l.principal_amount) AS total_principal,
    SUM(l.outstanding_balance) AS total_outstanding,
    AVG(l.interest_rate) AS avg_interest_rate,
    AVG(l.tenure_months) AS avg_tenure_months,
    SUM(l.principal_amount - NVL(l.outstanding_balance, 0)) AS total_repaid
FROM LOANS l
GROUP BY l.loan_type, l.status
ORDER BY l.loan_type, l.status;

-- 5. Overdue Loans Report
SELECT 
    l.loan_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.phone,
    c.email,
    l.loan_type,
    l.principal_amount,
    l.outstanding_balance,
    l.emi_amount,
    l.disbursement_date,
    FLOOR(MONTHS_BETWEEN(SYSDATE, l.disbursement_date)) AS months_since_disbursement,
    l.tenure_months,
    CASE 
        WHEN FLOOR(MONTHS_BETWEEN(SYSDATE, l.disbursement_date)) > l.tenure_months 
        THEN 'OVERDUE'
        ELSE 'CURRENT'
    END AS loan_status_detail
FROM LOANS l
JOIN CUSTOMERS c ON l.customer_id = c.customer_id
WHERE l.status = 'DISBURSED' 
AND l.outstanding_balance > 0
ORDER BY months_since_disbursement DESC;

-- 6. Top 10 Customers by Transaction Volume (Last 6 Months)
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(th.transaction_id) AS transaction_count,
    SUM(th.amount) AS total_transaction_amount,
    AVG(th.amount) AS avg_transaction_amount
FROM CUSTOMERS c
JOIN ACCOUNTS a ON c.customer_id = a.customer_id
JOIN TRANSACTION_HISTORY th ON a.account_id = th.account_id
WHERE th.transaction_date >= ADD_MONTHS(SYSDATE, -6)
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_transaction_amount DESC
FETCH FIRST 10 ROWS ONLY;

-- 7. Daily Transaction Summary (Last 30 Days)
SELECT 
    TO_CHAR(th.transaction_date, 'YYYY-MM-DD') AS transaction_date,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN th.transaction_type = 'DEPOSIT' THEN th.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN th.transaction_type = 'WITHDRAWAL' THEN th.amount ELSE 0 END) AS total_withdrawals,
    SUM(CASE WHEN th.transaction_type IN ('TRANSFER_IN', 'TRANSFER_OUT') THEN th.amount ELSE 0 END) AS total_transfers,
    SUM(th.amount) AS total_amount
FROM TRANSACTION_HISTORY th
WHERE th.transaction_date >= SYSDATE - 30
GROUP BY TO_CHAR(th.transaction_date, 'YYYY-MM-DD')
ORDER BY transaction_date DESC;

-- 8. Loan Performance Analysis
SELECT 
    l.loan_type,
    COUNT(*) AS total_loans,
    SUM(l.principal_amount) AS total_sanctioned,
    SUM(CASE WHEN l.status = 'DISBURSED' THEN l.principal_amount ELSE 0 END) AS total_disbursed,
    SUM(CASE WHEN l.status = 'CLOSED' THEN l.principal_amount ELSE 0 END) AS total_closed,
    ROUND(
        (SUM(CASE WHEN l.status = 'CLOSED' THEN l.principal_amount ELSE 0 END) / 
         NULLIF(SUM(CASE WHEN l.status = 'DISBURSED' THEN l.principal_amount ELSE 0 END), 0)) * 100, 2
    ) AS closure_rate_percent,
    SUM(
        SELECT SUM(lp.payment_amount) 
        FROM LOAN_PAYMENTS lp 
        WHERE lp.loan_id = l.loan_id
    ) AS total_collections
FROM LOANS l
GROUP BY l.loan_type
ORDER BY total_sanctioned DESC;

-- 9. Customer Profitability Analysis
WITH customer_revenue AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        -- Interest earned from loans
        SUM(
            CASE WHEN l.status IN ('DISBURSED', 'CLOSED') 
            THEN (
                SELECT SUM(lp.interest_component) 
                FROM LOAN_PAYMENTS lp 
                WHERE lp.loan_id = l.loan_id
            ) ELSE 0 END
        ) AS interest_income,
        -- Account maintenance (assumed fee structure)
        COUNT(DISTINCT a.account_id) * 100 AS account_fees,
        -- Transaction fees (assumed)
        (
            SELECT COUNT(*) 
            FROM TRANSACTION_HISTORY th 
            JOIN ACCOUNTS acc ON th.account_id = acc.account_id 
            WHERE acc.customer_id = c.customer_id
        ) * 2 AS transaction_fees
    FROM CUSTOMERS c
    LEFT JOIN ACCOUNTS a ON c.customer_id = a.customer_id
    LEFT JOIN LOANS l ON c.customer_id = l.customer_id
    WHERE c.status = 'ACTIVE'
    GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
    customer_id,
    customer_name,
    NVL(interest_income, 0) AS loan_interest_income,
    account_fees,
    transaction_fees,
    (NVL(interest_income, 0) + account_fees + transaction_fees) AS total_revenue
FROM customer_revenue
ORDER BY total_revenue DESC;

-- 10. Account Activity Report (Dormant Account Detection)
SELECT 
    a.account_id,
    a.account_number,
    c.first_name || ' ' || c.last_name AS customer_name,
    at.type_name AS account_type,
    a.balance,
    a.opened_date,
    (
        SELECT MAX(th.transaction_date) 
        FROM TRANSACTION_HISTORY th 
        WHERE th.account_id = a.account_id
    ) AS last_transaction_date,
    CASE 
        WHEN (
            SELECT MAX(th.transaction_date) 
            FROM TRANSACTION_HISTORY th 
            WHERE th.account_id = a.account_id
        ) < SYSDATE - 90 THEN 'DORMANT'
        WHEN (
            SELECT MAX(th.transaction_date) 
            FROM TRANSACTION_HISTORY th 
            WHERE th.account_id = a.account_id
        ) < SYSDATE - 30 THEN 'INACTIVE'
        ELSE 'ACTIVE'
    END AS activity_status
FROM ACCOUNTS a
JOIN CUSTOMERS c ON a.customer_id = c.customer_id
JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
WHERE a.status = 'ACTIVE'
ORDER BY last_transaction_date ASC NULLS FIRST;

-- 11. Monthly Interest Calculation Report (for Savings Accounts)
SELECT 
    a.account_id,
    a.account_number,
    c.first_name || ' ' || c.last_name AS customer_name,
    a.balance AS current_balance,
    at.interest_rate,
    calculate_interest(a.balance, at.interest_rate, 30) AS monthly_interest,
    calculate_interest(a.balance, at.interest_rate, 365) AS annual_interest
FROM ACCOUNTS a
JOIN CUSTOMERS c ON a.customer_id = c.customer_id
JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
WHERE a.status = 'ACTIVE' 
AND at.type_name = 'SAVINGS'
AND a.balance > 0
ORDER BY monthly_interest DESC;

-- 12. Loan EMI Schedule Summary
SELECT 
    l.loan_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    l.loan_type,
    l.principal_amount,
    l.interest_rate,
    l.tenure_months,
    l.emi_amount,
    l.outstanding_balance,
    COUNT(lp.payment_id) AS payments_made,
    SUM(lp.payment_amount) AS total_paid,
    SUM(lp.principal_component) AS principal_paid,
    SUM(lp.interest_component) AS interest_paid,
    (l.tenure_months - COUNT(lp.payment_id)) AS remaining_emis
FROM LOANS l
JOIN CUSTOMERS c ON l.customer_id = c.customer_id
LEFT JOIN LOAN_PAYMENTS lp ON l.loan_id = lp.loan_id
WHERE l.status IN ('DISBURSED', 'CLOSED')
GROUP BY l.loan_id, c.first_name, c.last_name, l.loan_type, 
         l.principal_amount, l.interest_rate, l.tenure_months, 
         l.emi_amount, l.outstanding_balance
ORDER BY l.loan_id;