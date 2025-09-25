-- Banking Management System - Table Creation Script
-- Author: Shivam Dubey
-- Description: Core database schema for banking operations

-- Drop tables if they exist (for clean setup)
DROP TABLE LOAN_PAYMENTS CASCADE CONSTRAINTS;
DROP TABLE LOAN_AUDIT CASCADE CONSTRAINTS;
DROP TABLE LOANS CASCADE CONSTRAINTS;
DROP TABLE TRANSACTION_HISTORY CASCADE CONSTRAINTS;
DROP TABLE ACCOUNTS CASCADE CONSTRAINTS;
DROP TABLE CUSTOMERS CASCADE CONSTRAINTS;
DROP TABLE ACCOUNT_TYPES CASCADE CONSTRAINTS;

-- Create Account Types lookup table
CREATE TABLE ACCOUNT_TYPES (
    type_id NUMBER(2) PRIMARY KEY,
    type_name VARCHAR2(20) NOT NULL UNIQUE,
    min_balance NUMBER(10,2) DEFAULT 0,
    interest_rate NUMBER(5,2) DEFAULT 0,
    created_date DATE DEFAULT SYSDATE
);

-- Create Customers table
CREATE TABLE CUSTOMERS (
    customer_id NUMBER(10) PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    email VARCHAR2(100) UNIQUE,
    phone VARCHAR2(15),
    address VARCHAR2(200),
    date_of_birth DATE,
    created_date DATE DEFAULT SYSDATE,
    updated_date DATE DEFAULT SYSDATE,
    status VARCHAR2(10) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

-- Create Accounts table
CREATE TABLE ACCOUNTS (
    account_id NUMBER(12) PRIMARY KEY,
    customer_id NUMBER(10) NOT NULL,
    account_type_id NUMBER(2) NOT NULL,
    balance NUMBER(15,2) DEFAULT 0 CHECK (balance >= 0),
    account_number VARCHAR2(20) UNIQUE NOT NULL,
    opened_date DATE DEFAULT SYSDATE,
    closed_date DATE,
    status VARCHAR2(10) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED', 'SUSPENDED')),
    CONSTRAINT fk_accounts_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id),
    CONSTRAINT fk_accounts_type FOREIGN KEY (account_type_id) REFERENCES ACCOUNT_TYPES(type_id)
);

-- Create Transaction History table
CREATE TABLE TRANSACTION_HISTORY (
    transaction_id NUMBER(15) PRIMARY KEY,
    account_id NUMBER(12) NOT NULL,
    transaction_type VARCHAR2(20) NOT NULL CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT')),
    amount NUMBER(15,2) NOT NULL CHECK (amount > 0),
    balance_after NUMBER(15,2) NOT NULL,
    description VARCHAR2(200),
    transaction_date DATE DEFAULT SYSDATE,
    reference_account_id NUMBER(12), -- For transfers
    CONSTRAINT fk_transaction_account FOREIGN KEY (account_id) REFERENCES ACCOUNTS(account_id),
    CONSTRAINT fk_transaction_ref_account FOREIGN KEY (reference_account_id) REFERENCES ACCOUNTS(account_id)
);

-- Create Loans table
CREATE TABLE LOANS (
    loan_id NUMBER(12) PRIMARY KEY,
    customer_id NUMBER(10) NOT NULL,
    loan_type VARCHAR2(20) NOT NULL CHECK (loan_type IN ('PERSONAL', 'HOME', 'CAR', 'BUSINESS')),
    principal_amount NUMBER(15,2) NOT NULL CHECK (principal_amount > 0),
    interest_rate NUMBER(5,2) NOT NULL CHECK (interest_rate > 0),
    tenure_months NUMBER(3) NOT NULL CHECK (tenure_months > 0),
    emi_amount NUMBER(10,2),
    outstanding_balance NUMBER(15,2),
    application_date DATE DEFAULT SYSDATE,
    approval_date DATE,
    disbursement_date DATE,
    status VARCHAR2(15) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'DISBURSED', 'CLOSED')),
    CONSTRAINT fk_loans_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id)
);

-- Create Loan Payments table
CREATE TABLE LOAN_PAYMENTS (
    payment_id NUMBER(12) PRIMARY KEY,
    loan_id NUMBER(12) NOT NULL,
    payment_amount NUMBER(10,2) NOT NULL CHECK (payment_amount > 0),
    payment_date DATE DEFAULT SYSDATE,
    principal_component NUMBER(10,2),
    interest_component NUMBER(10,2),
    outstanding_after_payment NUMBER(15,2),
    CONSTRAINT fk_loan_payments FOREIGN KEY (loan_id) REFERENCES LOANS(loan_id)
);

-- Create Loan Audit table for tracking changes
CREATE TABLE LOAN_AUDIT (
    audit_id NUMBER(12) PRIMARY KEY,
    loan_id NUMBER(12) NOT NULL,
    old_status VARCHAR2(15),
    new_status VARCHAR2(15),
    changed_by VARCHAR2(50),
    change_date DATE DEFAULT SYSDATE,
    remarks VARCHAR2(200)
);

-- Create sequences for primary keys
CREATE SEQUENCE seq_customer_id START WITH 1001 INCREMENT BY 1;
CREATE SEQUENCE seq_account_id START WITH 100001 INCREMENT BY 1;
CREATE SEQUENCE seq_transaction_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_loan_id START WITH 10001 INCREMENT BY 1;
CREATE SEQUENCE seq_payment_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_audit_id START WITH 1 INCREMENT BY 1;

-- Create indexes for better performance
CREATE INDEX idx_accounts_customer ON ACCOUNTS(customer_id);
CREATE INDEX idx_transactions_account ON TRANSACTION_HISTORY(account_id);
CREATE INDEX idx_transactions_date ON TRANSACTION_HISTORY(transaction_date);
CREATE INDEX idx_loans_customer ON LOANS(customer_id);
CREATE INDEX idx_loans_status ON LOANS(status);
CREATE INDEX idx_payments_loan ON LOAN_PAYMENTS(loan_id);

COMMIT;

PROMPT 'Banking Management System tables created successfully!'