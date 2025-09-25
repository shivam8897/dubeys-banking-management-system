-- Banking Management System - Backup and Restore Procedures
-- Author: BMS Development Team
-- Description: Database backup, restore, and maintenance procedures

-- Create directory for backups (run as SYSDBA)
-- CREATE OR REPLACE DIRECTORY BMS_BACKUP_DIR AS '/opt/backups/bms';
-- GRANT READ, WRITE ON DIRECTORY BMS_BACKUP_DIR TO bms_user;

-- Backup procedure using Data Pump
CREATE OR REPLACE PROCEDURE backup_bms_database(
    p_backup_name IN VARCHAR2 DEFAULT NULL
) AS
    v_backup_name VARCHAR2(100);
    v_job_handle NUMBER;
    v_job_state VARCHAR2(30);
BEGIN
    -- Generate backup name if not provided
    v_backup_name := NVL(p_backup_name, 'BMS_BACKUP_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS'));
    
    -- Create Data Pump export job
    v_job_handle := DBMS_DATAPUMP.OPEN(
        operation => 'EXPORT',
        job_mode => 'SCHEMA',
        job_name => 'BMS_EXPORT_JOB'
    );
    
    -- Add schema to export
    DBMS_DATAPUMP.ADD_FILTER(v_job_handle, 'SCHEMA_EXPR', 'IN (''' || USER || ''')');
    
    -- Set export file
    DBMS_DATAPUMP.ADD_FILE(
        handle => v_job_handle,
        filename => v_backup_name || '.dmp',
        directory => 'BMS_BACKUP_DIR',
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE
    );
    
    -- Set log file
    DBMS_DATAPUMP.ADD_FILE(
        handle => v_job_handle,
        filename => v_backup_name || '.log',
        directory => 'BMS_BACKUP_DIR',
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE
    );
    
    -- Start the export job
    DBMS_DATAPUMP.START_JOB(v_job_handle);
    
    -- Wait for job completion
    DBMS_DATAPUMP.WAIT_FOR_JOB(v_job_handle, v_job_state);
    
    -- Close the job
    DBMS_DATAPUMP.DETACH(v_job_handle);
    
    DBMS_OUTPUT.PUT_LINE('Backup completed: ' || v_backup_name);
    
    -- Log backup in audit table
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status,
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, 0, 'BACKUP', 'COMPLETED',
        USER, SYSDATE, 'Database backup: ' || v_backup_name
    );
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Clean up job if error occurs
        BEGIN
            DBMS_DATAPUMP.DETACH(v_job_handle);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- Log error
        INSERT INTO LOAN_AUDIT (
            audit_id, loan_id, old_status, new_status,
            changed_by, change_date, remarks
        ) VALUES (
            seq_audit_id.NEXTVAL, 0, 'BACKUP', 'FAILED',
            USER, SYSDATE, 'Backup failed: ' || SQLERRM
        );
        COMMIT;
        
        RAISE_APPLICATION_ERROR(-20500, 'Backup failed: ' || SQLERRM);
END backup_bms_database;
/

-- Restore procedure using Data Pump
CREATE OR REPLACE PROCEDURE restore_bms_database(
    p_backup_file IN VARCHAR2
) AS
    v_job_handle NUMBER;
    v_job_state VARCHAR2(30);
BEGIN
    -- Create Data Pump import job
    v_job_handle := DBMS_DATAPUMP.OPEN(
        operation => 'IMPORT',
        job_mode => 'SCHEMA',
        job_name => 'BMS_IMPORT_JOB'
    );
    
    -- Set import file
    DBMS_DATAPUMP.ADD_FILE(
        handle => v_job_handle,
        filename => p_backup_file,
        directory => 'BMS_BACKUP_DIR',
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE
    );
    
    -- Set log file
    DBMS_DATAPUMP.ADD_FILE(
        handle => v_job_handle,
        filename => 'RESTORE_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') || '.log',
        directory => 'BMS_BACKUP_DIR',
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE
    );
    
    -- Set table exists action
    DBMS_DATAPUMP.SET_PARAMETER(v_job_handle, 'TABLE_EXISTS_ACTION', 'REPLACE');
    
    -- Start the import job
    DBMS_DATAPUMP.START_JOB(v_job_handle);
    
    -- Wait for job completion
    DBMS_DATAPUMP.WAIT_FOR_JOB(v_job_handle, v_job_state);
    
    -- Close the job
    DBMS_DATAPUMP.DETACH(v_job_handle);
    
    DBMS_OUTPUT.PUT_LINE('Restore completed from: ' || p_backup_file);
    
    -- Log restore in audit table
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status,
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, 0, 'RESTORE', 'COMPLETED',
        USER, SYSDATE, 'Database restored from: ' || p_backup_file
    );
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Clean up job if error occurs
        BEGIN
            DBMS_DATAPUMP.DETACH(v_job_handle);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- Log error
        INSERT INTO LOAN_AUDIT (
            audit_id, loan_id, old_status, new_status,
            changed_by, change_date, remarks
        ) VALUES (
            seq_audit_id.NEXTVAL, 0, 'RESTORE', 'FAILED',
            USER, SYSDATE, 'Restore failed: ' || SQLERRM
        );
        COMMIT;
        
        RAISE_APPLICATION_ERROR(-20501, 'Restore failed: ' || SQLERRM);
END restore_bms_database;
/

-- Database maintenance procedure
CREATE OR REPLACE PROCEDURE maintain_bms_database AS
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting BMS Database Maintenance...');
    
    -- Update table statistics
    DBMS_OUTPUT.PUT_LINE('Updating table statistics...');
    DBMS_STATS.GATHER_SCHEMA_STATS(
        ownname => USER,
        estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO',
        cascade => TRUE
    );
    
    -- Rebuild indexes if needed
    DBMS_OUTPUT.PUT_LINE('Checking index health...');
    FOR idx IN (
        SELECT index_name 
        FROM USER_INDEXES 
        WHERE table_name IN ('CUSTOMERS', 'ACCOUNTS', 'TRANSACTION_HISTORY', 'LOANS')
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'ALTER INDEX ' || idx.index_name || ' REBUILD ONLINE';
            DBMS_OUTPUT.PUT_LINE('Rebuilt index: ' || idx.index_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not rebuild ' || idx.index_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    -- Clean up old audit records (keep last 6 months)
    DBMS_OUTPUT.PUT_LINE('Cleaning up old audit records...');
    DELETE FROM LOAN_AUDIT 
    WHERE change_date < ADD_MONTHS(SYSDATE, -6);
    
    DBMS_OUTPUT.PUT_LINE('Deleted ' || SQL%ROWCOUNT || ' old audit records');
    
    -- Analyze table sizes
    DBMS_OUTPUT.PUT_LINE('Table size analysis:');
    FOR rec IN (
        SELECT table_name, num_rows, 
               ROUND(num_rows * avg_row_len / 1024 / 1024, 2) as size_mb
        FROM USER_TABLES 
        WHERE table_name IN ('CUSTOMERS', 'ACCOUNTS', 'TRANSACTION_HISTORY', 'LOANS', 'LOAN_PAYMENTS')
        ORDER BY num_rows DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(rec.table_name || ': ' || 
                           NVL(rec.num_rows, 0) || ' rows, ' || 
                           NVL(rec.size_mb, 0) || ' MB');
    END LOOP;
    
    COMMIT;
    
    -- Log maintenance completion
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status,
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, 0, 'MAINTENANCE', 'COMPLETED',
        USER, SYSDATE, 'Database maintenance completed successfully'
    );
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('BMS Database Maintenance completed successfully!');
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        
        -- Log maintenance error
        INSERT INTO LOAN_AUDIT (
            audit_id, loan_id, old_status, new_status,
            changed_by, change_date, remarks
        ) VALUES (
            seq_audit_id.NEXTVAL, 0, 'MAINTENANCE', 'FAILED',
            USER, SYSDATE, 'Maintenance failed: ' || SQLERRM
        );
        COMMIT;
        
        RAISE_APPLICATION_ERROR(-20502, 'Maintenance failed: ' || SQLERRM);
END maintain_bms_database;
/

-- Health check procedure
CREATE OR REPLACE PROCEDURE health_check_bms AS
    v_customer_count NUMBER;
    v_account_count NUMBER;
    v_transaction_count NUMBER;
    v_loan_count NUMBER;
    v_total_balance NUMBER;
    v_issues NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('BMS Database Health Check');
    DBMS_OUTPUT.PUT_LINE('========================');
    
    -- Check customer data integrity
    SELECT COUNT(*) INTO v_customer_count FROM CUSTOMERS;
    DBMS_OUTPUT.PUT_LINE('Total Customers: ' || v_customer_count);
    
    -- Check for customers without accounts
    SELECT COUNT(*) INTO v_customer_count 
    FROM CUSTOMERS c 
    WHERE NOT EXISTS (SELECT 1 FROM ACCOUNTS a WHERE a.customer_id = c.customer_id);
    
    IF v_customer_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_customer_count || ' customers without accounts');
        v_issues := v_issues + 1;
    END IF;
    
    -- Check account data integrity
    SELECT COUNT(*) INTO v_account_count FROM ACCOUNTS WHERE status = 'ACTIVE';
    DBMS_OUTPUT.PUT_LINE('Active Accounts: ' || v_account_count);
    
    -- Check for negative balances
    SELECT COUNT(*) INTO v_account_count FROM ACCOUNTS WHERE balance < 0;
    IF v_account_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_account_count || ' accounts with negative balance');
        v_issues := v_issues + 1;
    END IF;
    
    -- Check transaction integrity
    SELECT COUNT(*) INTO v_transaction_count FROM TRANSACTION_HISTORY;
    DBMS_OUTPUT.PUT_LINE('Total Transactions: ' || v_transaction_count);
    
    -- Check for orphaned transactions
    SELECT COUNT(*) INTO v_transaction_count 
    FROM TRANSACTION_HISTORY th 
    WHERE NOT EXISTS (SELECT 1 FROM ACCOUNTS a WHERE a.account_id = th.account_id);
    
    IF v_transaction_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || v_transaction_count || ' orphaned transactions');
        v_issues := v_issues + 1;
    END IF;
    
    -- Check loan data integrity
    SELECT COUNT(*) INTO v_loan_count FROM LOANS WHERE status IN ('APPROVED', 'DISBURSED');
    DBMS_OUTPUT.PUT_LINE('Active Loans: ' || v_loan_count);
    
    -- Check total system balance
    SELECT SUM(balance) INTO v_total_balance FROM ACCOUNTS WHERE status = 'ACTIVE';
    DBMS_OUTPUT.PUT_LINE('Total System Balance: ₹' || TO_CHAR(v_total_balance, '999,999,999.99'));
    
    -- Check database connectivity
    SELECT 1 INTO v_customer_count FROM DUAL;
    DBMS_OUTPUT.PUT_LINE('Database Connectivity: OK');
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE('========================');
    IF v_issues = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Health Check Status: HEALTHY');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Health Check Status: ' || v_issues || ' ISSUES FOUND');
    END IF;
    
    -- Log health check
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status,
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, 0, 'HEALTH_CHECK', 
        CASE WHEN v_issues = 0 THEN 'HEALTHY' ELSE 'ISSUES_FOUND' END,
        USER, SYSDATE, v_issues || ' issues found during health check'
    );
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Health Check Failed: ' || SQLERRM);
        
        INSERT INTO LOAN_AUDIT (
            audit_id, loan_id, old_status, new_status,
            changed_by, change_date, remarks
        ) VALUES (
            seq_audit_id.NEXTVAL, 0, 'HEALTH_CHECK', 'FAILED',
            USER, SYSDATE, 'Health check failed: ' || SQLERRM
        );
        COMMIT;
END health_check_bms;
/

-- Create automated backup job
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'DAILY_BMS_BACKUP',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN backup_bms_database(); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0',
        enabled         => FALSE, -- Enable manually after testing
        comments        => 'Daily backup of BMS database'
    );
END;
/

-- Create weekly maintenance job
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'WEEKLY_BMS_MAINTENANCE',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN maintain_bms_database(); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=3; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Weekly maintenance of BMS database'
    );
END;
/

COMMIT;

PROMPT 'Backup and maintenance procedures created successfully!';
PROMPT '';
PROMPT 'Available procedures:';
PROMPT '- backup_bms_database(backup_name)';
PROMPT '- restore_bms_database(backup_file)';
PROMPT '- maintain_bms_database()';
PROMPT '- health_check_bms()';
PROMPT '';
PROMPT 'Scheduled jobs created:';
PROMPT '- DAILY_BMS_BACKUP (disabled by default)';
PROMPT '- WEEKLY_BMS_MAINTENANCE (enabled)';
PROMPT '';
PROMPT 'To run procedures:';
PROMPT 'EXEC backup_bms_database();';
PROMPT 'EXEC maintain_bms_database();';
PROMPT 'EXEC health_check_bms();';