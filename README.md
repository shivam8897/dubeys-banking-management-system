# Dubey's Banking Management System (DBMS)

A comprehensive end-to-end banking system built with PL/SQL backend and modern UI frontend.
**Developed by Shivam Dubey**

## Features

- **Customer Management**: Add, edit, delete customers and view their details
- **Account Management**: Support for savings and current accounts with balance tracking
- **Transaction Processing**: Deposits, withdrawals, and fund transfers with audit trails
- **Loan Management**: Loan applications, approvals, EMI calculations, and payment tracking
- **Comprehensive Reporting**: Customer summaries, transaction reports, and loan analytics
- **Advanced PL/SQL**: Stored procedures, functions, triggers, packages, and exception handling

## Project Structure

```
Banking-Management-System/
├── README.md
├── SQL/
│   ├── tables.sql
│   ├── sample_data.sql
│   ├── procedures.sql
│   ├── functions.sql
│   ├── triggers.sql
│   └── packages.sql
├── UI/
│   ├── app.py
│   └── templates/
├── Reports/
│   └── report_queries.sql
└── .gitignore
```

## Setup Instructions

### Prerequisites
- Oracle Database (11g or higher)
- Python 3.7+ (for web interface)
- Oracle Instant Client (for Python connectivity)

### 1. Database Setup
```sql
-- Connect to your Oracle database as a user with CREATE privileges
-- Run the complete setup script:
@setup_database.sql

-- Or run individual scripts in order:
@SQL/tables.sql
@SQL/functions.sql
@SQL/procedures.sql
@SQL/triggers.sql
@SQL/packages.sql
@SQL/sample_data.sql
```

### 2. Web Interface Setup (Optional)
```bash
# Navigate to UI directory
cd UI

# Install Python dependencies
pip install -r requirements.txt

# Update database connection in app.py
# Edit the DB_CONFIG section with your database details:
DB_CONFIG = {
    'user': 'your_username',
    'password': 'your_password',
    'dsn': 'localhost:1521/XE'  # Adjust as needed
}

# Run the Flask application
python app.py
```

### 3. Access the System
- **Web Interface**: http://localhost:5000
- **Database**: Connect directly using SQL*Plus, SQL Developer, or any Oracle client

### 4. Test the System
The setup includes sample data:
- 5 customers with various account types
- Sample transactions and transfers
- Loan applications in different stages
- Use the web interface or SQL commands to test functionality

## Core Workflow

1. Customer Creation → Account Opening → Transaction Processing → Loan Management → Reporting

## Technologies Used

- **Backend**: Oracle PL/SQL
- **Frontend**: Python Flask (optional)
- **Database**: Oracle Database
- **Version Control**: Git

## Author

Dubey's Banking Management System - PL/SQL Implementation by Shivam Dubey