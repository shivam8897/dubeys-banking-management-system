-- Banking Management System - Performance Tuning
-- Author: BMS Development Team
-- Description: Performance optimization scripts and monitoring

-- Create additional indexes for better query performance
PROMPT 'Creating performance indexes...';

-- Composite indexes for common query patterns
CREATE INDEX idx_accounts_customer_status ON ACCOUNTS(customer_id, status);
CREATE INDEX idx_transactions_account_date ON TRANSACTION_HISTORY(account_id, transaction_date);
CREATE INDEX idx_transactions_type_date ON TRANSACTION_HISTORY(transaction_type, transaction_date);
CREATE INDEX idx_loans_customer_status ON LOANS(customer_id, status);
CREATE INDEX idx_loan_payments_date ON LOAN_PAYMENTS(loan_id, payment_date);
CREATE INDEX idx_customers_email ON CUSTOMERS(email);
CREATE INDEX idx_customers_phone ON CUSTOMERS(phone);

-- Function-based indexes
CREATE INDEX idx_customers_name_upper ON CUSTOMERS(UPPER(first_name || ' ' || last_name));
CREATE INDEX idx_accounts_balance_range ON ACCOUNTS(
    CASE 
        WHEN balance < 10000 THEN 'LOW'
        WHEN balance < 100000 THEN 'MEDIUM'
        ELSE 'HIGH'
    END
);

-- Partitioning for large transaction table (if needed in future)
-- This is commented out as it requires table recreation
/*
-- Create partitioned transaction history table for better performance
CREATE TABLE TRANSACTION_HISTORY_PARTITIONED (
    transaction_id NUMBER(15) PRIMARY KEY,
    account_id NUMBER(12) NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL,
    amount NUMBER(15,2) NOT NULL,
    balance_after NUMBER(15,2) NOT NULL,
    description VARCHAR2(200),
    transaction_date DATE DEFAULT SYSDATE,
    reference_account_id NUMBER(12)
)
PARTITION BY RANGE (transaction_date) (
    PARTITION p_2023 VALUES LESS THAN (DATE '2024-01-01'),
    PARTITION p_2024 VALUES LESS THAN (DATE '2025-01-01'),
    PARTITION p_2025 VALUES LESS THAN (DATE '2026-01-01'),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
*/

-- Performance monitoring views
CREATE OR REPLACE VIEW v_account_performance AS
SELECT 
    a.account_id,
    a.account_number,
    c.first_name || ' ' || c.last_name as customer_name,
    COUNT(th.transaction_id) as transaction_count,
    SUM(CASE WHEN th.transaction_type = 'DEPOSIT' THEN th.amount ELSE 0 END) as total_deposits,
    SUM(CASE WHEN th.transaction_type = 'WITHDRAWAL' THEN th.amount ELSE 0 END) as total_withdrawals,
    MAX(th.transaction_date) as last_transaction_date,
    a.balance as current_balance
FROM ACCOUNTS a
JOIN CUSTOMERS c ON a.customer_id = c.customer_id
LEFT JOIN TRANSACTION_HISTORY th ON a.account_id = th.account_id
WHERE a.status = 'ACTIVE'
GROUP BY a.account_id, a.account_number, c.first_name, c.last_name, a.balance;

CREATE OR REPLACE VIEW v_loan_performance AS
SELECT 
    l.loan_type,
    COUNT(*) as total_loans,
    SUM(l.principal_amount) as total_principal,
    AVG(l.interest_rate) as avg_interest_rate,
    SUM(CASE WHEN l.status = 'APPROVED' THEN 1 ELSE 0 END) as approved_count,
    SUM(CASE WHEN l.status = 'REJECTED' THEN 1 ELSE 0 END) as rejected_count,
    SUM(CASE WHEN l.status = 'CLOSED' THEN 1 ELSE 0 END) as closed_count,
    ROUND(
        SUM(CASE WHEN l.status = 'APPROVED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
    ) as approval_rate_percent
FROM LOANS l
GROUP BY l.loan_type;

-- Performance tuning procedures
CREATE OR REPLACE PROCEDURE analyze_table_performance AS
BEGIN
    -- Gather fresh statistics
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname => USER,
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade => TRUE
    );
    
    DBMS_OUTPUT.PUT_LINE('Schema statistics updated successfully');
END;
/

CREATE OR REPLACE PROCEDURE monitor_slow_queries AS
BEGIN
    -- This would typically query V$SQL or AWR data
    -- For demonstration, we'll show table access patterns
    
    DBMS_OUTPUT.PUT_LINE('=== Table Access Patterns ===');
    
    FOR rec IN (
        SELECT table_name, num_rows, last_analyzed
        FROM USER_TABLES
        WHERE table_name IN ('CUSTOMERS', 'ACCOUNTS', 'TRANSACTION_HISTORY', 'LOANS')
        ORDER BY num_rows DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.table_name || ': ' || 
                           NVL(rec.num_rows, 0) || ' rows, analyzed: ' || 
                           NVL(TO_CHAR(rec.last_analyzed, 'YYYY-MM-DD'), 'Never'));
    END LOOP;
END;
/

-- Bulk operations for better performance
CREATE OR REPLACE PROCEDURE bulk_process_transactions(
    p_batch_size IN NUMBER DEFAULT 1000
) AS
    TYPE t_transaction_array IS TABLE OF TRANSACTION_HISTORY%ROWTYPE;
    v_transactions t_transaction_array;
    
    CURSOR c_pending_transactions IS
        SELECT * FROM TRANSACTION_HISTORY
        WHERE transaction_date >= SYSDATE - 1
        ORDER BY transaction_id;
BEGIN
    OPEN c_pending_transactions;
    
    LOOP
        FETCH c_pending_transactions BULK COLLECT INTO v_transactions LIMIT p_batch_size;
        
        -- Process transactions in batches
        FORALL i IN 1..v_transactions.COUNT
            UPDATE TRANSACTION_HISTORY 
            SET description = description || ' [Processed]'
            WHERE transaction_id = v_transactions(i).transaction_id;
        
        COMMIT;
        
        EXIT WHEN v_transactions.COUNT < p_batch_size;
    END LOOP;
    
    CLOSE c_pending_transactions;
    
    DBMS_OUTPUT.PUT_LINE('Bulk processing completed');
END;
/

-- Performance monitoring function
CREATE OR REPLACE FUNCTION get_system_performance RETURN SYS_REFCURSOR AS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT 
            'Database Size' as metric,
            ROUND(SUM(bytes)/1024/1024, 2) || ' MB' as value
        FROM USER_SEGMENTS
        UNION ALL
        SELECT 
            'Total Customers',
            TO_CHAR(COUNT(*))
        FROM CUSTOMERS
        UNION ALL
        SELECT 
            'Total Accounts',
            TO_CHAR(COUNT(*))
        FROM ACCOUNTS
        UNION ALL
        SELECT 
            'Daily Transactions',
            TO_CHAR(COUNT(*))
        FROM TRANSACTION_HISTORY
        WHERE transaction_date >= TRUNC(SYSDATE)
        UNION ALL
        SELECT 
            'Active Loans',
            TO_CHAR(COUNT(*))
        FROM LOANS
        WHERE status IN ('APPROVED', 'DISBURSED');
    
    RETURN v_cursor;
END;
/

-- Create materialized view for reporting (refresh daily)
CREATE MATERIALIZED VIEW mv_daily_summary
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    TRUNC(th.transaction_date) as transaction_date,
    th.transaction_type,
    COUNT(*) as transaction_count,
    SUM(th.amount) as total_amount,
    AVG(th.amount) as avg_amount
FROM TRANSACTION_HISTORY th
WHERE th.transaction_date >= SYSDATE - 365  -- Last year
GROUP BY TRUNC(th.transaction_date), th.transaction_type;

-- Schedule materialized view refresh
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'REFRESH_DAILY_SUMMARY_MV',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DBMS_MVIEW.REFRESH(''MV_DAILY_SUMMARY'', ''C'');',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=1; BYMINUTE=30; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily refresh of summary materialized view'
    );
END;
/

COMMIT;

-- Display performance summary
PROMPT 'Performance tuning completed!';
PROMPT '================================';
PROMPT 'Indexes created for optimal query performance';
PROMPT 'Performance monitoring views created:';
PROMPT '- v_account_performance';
PROMPT '- v_loan_performance';
PROMPT '';
PROMPT 'Performance procedures created:';
PROMPT '- analyze_table_performance';
PROMPT '- monitor_slow_queries';
PROMPT '- bulk_process_transactions';
PROMPT '';
PROMPT 'Materialized view created: mv_daily_summary';
PROMPT 'Scheduled job created: REFRESH_DAILY_SUMMARY_MV';
PROMPT '';
PROMPT 'To monitor performance:';
PROMPT 'SELECT * FROM TABLE(get_system_performance);';
PROMPT 'EXEC monitor_slow_queries;';