-- Banking Management System - Scheduler Jobs
-- Author: BMS Development Team
-- Description: Automated jobs for maintenance and calculations

-- Job 1: Monthly Interest Calculation for Savings Accounts
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'MONTHLY_INTEREST_CALCULATION',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
        DECLARE
            CURSOR c_savings_accounts IS
                SELECT a.account_id, a.balance, at.interest_rate
                FROM ACCOUNTS a
                JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
                WHERE a.status = ''ACTIVE'' 
                AND at.type_name = ''SAVINGS''
                AND a.balance > 0;
            
            v_interest_amount NUMBER;
        BEGIN
            FOR rec IN c_savings_accounts LOOP
                -- Calculate monthly interest
                v_interest_amount := calculate_interest(rec.balance, rec.interest_rate, 30);
                
                -- Credit interest to account
                IF v_interest_amount > 0 THEN
                    pkg_account_mgmt.deposit_money(
                        rec.account_id, 
                        v_interest_amount, 
                        ''Monthly interest credit''
                    );
                END IF;
            END LOOP;
            
            COMMIT;
        END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Monthly interest calculation for savings accounts'
    );
END;
/

-- Job 2: Daily Overdue Loan Reminder
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'DAILY_OVERDUE_LOAN_CHECK',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
        DECLARE
            CURSOR c_overdue_loans IS
                SELECT l.loan_id, l.customer_id, c.first_name, c.last_name, c.email, c.phone,
                       l.emi_amount, l.outstanding_balance,
                       FLOOR(MONTHS_BETWEEN(SYSDATE, l.disbursement_date)) as months_elapsed
                FROM LOANS l
                JOIN CUSTOMERS c ON l.customer_id = c.customer_id
                WHERE l.status = ''DISBURSED''
                AND l.outstanding_balance > 0
                AND FLOOR(MONTHS_BETWEEN(SYSDATE, l.disbursement_date)) > l.tenure_months;
        BEGIN
            FOR rec IN c_overdue_loans LOOP
                -- Log overdue loan for follow-up
                INSERT INTO LOAN_AUDIT (
                    audit_id, loan_id, old_status, new_status,
                    changed_by, change_date, remarks
                ) VALUES (
                    seq_audit_id.NEXTVAL, rec.loan_id, ''DISBURSED'', ''OVERDUE'',
                    ''SYSTEM'', SYSDATE, 
                    ''Loan overdue - '' || rec.months_elapsed || '' months elapsed''
                );
                
                -- In a real system, you would send email/SMS notifications here
                DBMS_OUTPUT.PUT_LINE(''Overdue loan notification for customer: '' || 
                                   rec.first_name || '' '' || rec.last_name);
            END LOOP;
            
            COMMIT;
        END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=9; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Daily check for overdue loans and notifications'
    );
END;
/

-- Job 3: Weekly Account Maintenance
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'WEEKLY_ACCOUNT_MAINTENANCE',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
        DECLARE
            v_maintenance_fee NUMBER := 50; -- Monthly maintenance fee
            CURSOR c_accounts IS
                SELECT account_id, balance
                FROM ACCOUNTS
                WHERE status = ''ACTIVE''
                AND account_type_id = 2 -- Current accounts only
                AND balance >= v_maintenance_fee;
        BEGIN
            -- Deduct maintenance fee from current accounts
            FOR rec IN c_accounts LOOP
                pkg_account_mgmt.withdraw_money(
                    rec.account_id,
                    v_maintenance_fee,
                    ''Monthly account maintenance fee''
                );
            END LOOP;
            
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                -- Log error for investigation
                INSERT INTO LOAN_AUDIT (
                    audit_id, loan_id, old_status, new_status,
                    changed_by, change_date, remarks
                ) VALUES (
                    seq_audit_id.NEXTVAL, 0, ''SYSTEM'', ''ERROR'',
                    ''SCHEDULER'', SYSDATE, 
                    ''Account maintenance job failed: '' || SQLERRM
                );
                COMMIT;
        END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=MON; BYHOUR=3; BYMINUTE=0; BYSECOND=0',
        enabled         => FALSE, -- Disabled by default, enable as needed
        comments        => 'Weekly account maintenance fee deduction'
    );
END;
/

-- Job 4: Database Statistics Update
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'UPDATE_TABLE_STATISTICS',
        job_type        => 'PLSQL_BLOCK',
        job_action      => '
        BEGIN
            -- Update statistics for better query performance
            DBMS_STATS.GATHER_TABLE_STATS(USER, ''CUSTOMERS'');
            DBMS_STATS.GATHER_TABLE_STATS(USER, ''ACCOUNTS'');
            DBMS_STATS.GATHER_TABLE_STATS(USER, ''TRANSACTION_HISTORY'');
            DBMS_STATS.GATHER_TABLE_STATS(USER, ''LOANS'');
            DBMS_STATS.GATHER_TABLE_STATS(USER, ''LOAN_PAYMENTS'');
            
            -- Log completion
            INSERT INTO LOAN_AUDIT (
                audit_id, loan_id, old_status, new_status,
                changed_by, change_date, remarks
            ) VALUES (
                seq_audit_id.NEXTVAL, 0, ''SYSTEM'', ''COMPLETED'',
                ''SCHEDULER'', SYSDATE, ''Database statistics updated successfully''
            );
            COMMIT;
        END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=1; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Weekly database statistics update for performance'
    );
END;
/

-- View all scheduled jobs
SELECT job_name, enabled, state, next_run_date, last_start_date
FROM USER_SCHEDULER_JOBS
WHERE job_name IN (
    'MONTHLY_INTEREST_CALCULATION',
    'DAILY_OVERDUE_LOAN_CHECK', 
    'WEEKLY_ACCOUNT_MAINTENANCE',
    'UPDATE_TABLE_STATISTICS'
);

COMMIT;

PROMPT 'Scheduler jobs created successfully!';
PROMPT 'Jobs created:';
PROMPT '1. MONTHLY_INTEREST_CALCULATION - Calculates and credits monthly interest';
PROMPT '2. DAILY_OVERDUE_LOAN_CHECK - Checks for overdue loans daily';
PROMPT '3. WEEKLY_ACCOUNT_MAINTENANCE - Deducts maintenance fees (disabled by default)';
PROMPT '4. UPDATE_TABLE_STATISTICS - Updates database statistics weekly';
PROMPT '';
PROMPT 'To enable/disable jobs:';
PROMPT 'EXEC DBMS_SCHEDULER.ENABLE(''job_name'');';
PROMPT 'EXEC DBMS_SCHEDULER.DISABLE(''job_name'');';
PROMPT '';
PROMPT 'To drop jobs:';
PROMPT 'EXEC DBMS_SCHEDULER.DROP_JOB(''job_name'');';