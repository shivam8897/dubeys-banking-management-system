"""
Dubey's Banking Management System - Demo Flask Application
Author: Sunny Dubey
Description: Demo web interface (works without Oracle database)
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from datetime import datetime
import logging

app = Flask(__name__)
app.secret_key = 'demo-secret-key'

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Demo data (simulating database)
demo_customers = [
    (1001, 'John', 'Doe', 'john.doe@email.com', '9876543210', '123 Main St', datetime(1985, 5, 15), datetime.now(), 'ACTIVE'),
    (1002, 'Jane', 'Smith', 'jane.smith@email.com', '9876543211', '456 Oak Ave', datetime(1990, 8, 22), datetime.now(), 'ACTIVE'),
    (1003, 'Robert', 'Johnson', 'robert.j@email.com', '9876543212', '789 Pine Rd', datetime(1982, 12, 10), datetime.now(), 'ACTIVE'),
]

demo_accounts = [
    (100001, 'SAV20250120000001', 'John Doe', 'SAVINGS', 56000.00, datetime.now(), 'ACTIVE'),
    (100002, 'SAV20250120000002', 'Jane Smith', 'SAVINGS', 34000.00, datetime.now(), 'ACTIVE'),
    (100003, 'SAV20250120000003', 'Robert Johnson', 'SAVINGS', 513000.00, datetime.now(), 'ACTIVE'),
]

demo_transactions = [
    (15, 100001, 'SAV20250120000001', 'DEPOSIT', 50000.00, 56000.00, 'Loan disbursement', datetime.now()),
    (14, 100003, 'SAV20250120000003', 'DEPOSIT', 500000.00, 513000.00, 'Loan disbursement', datetime.now()),
    (13, 100002, 'SAV20250120000002', 'DEPOSIT', 30000.00, 34000.00, 'Loan disbursement', datetime.now()),
]

demo_loans = [
    (10001, 'John Doe', 'PERSONAL', 50000.00, 12.5, 24, 2347.50, 45305.00, datetime.now(), 'DISBURSED'),
    (10002, 'Jane Smith', 'PERSONAL', 30000.00, 11.0, 18, 1806.50, 28193.50, datetime.now(), 'DISBURSED'),
    (10003, 'Robert Johnson', 'HOME', 500000.00, 8.5, 240, 4240.50, 495759.50, datetime.now(), 'DISBURSED'),
]

demo_account_types = [
    (1, 'SAVINGS', 1000),
    (2, 'CURRENT', 5000),
]

@app.route('/')
def index():
    """Home page"""
    return render_template('index.html')

@app.route('/customers')
def customers():
    """Customer management page"""
    return render_template('customers.html', customers=demo_customers)

@app.route('/add_customer', methods=['POST'])
def add_customer():
    """Add new customer (demo)"""
    try:
        # In real app, this would call the database
        customer_id = len(demo_customers) + 1001
        flash(f'Customer added successfully with ID: {customer_id}', 'success')
    except Exception as e:
        flash(f'Error adding customer: {str(e)}', 'error')
    
    return redirect(url_for('customers'))

@app.route('/accounts')
def accounts():
    """Account management page"""
    customers_for_dropdown = [(c[0], f"{c[1]} {c[2]}") for c in demo_customers]
    return render_template('accounts.html', 
                         accounts=demo_accounts, 
                         customers=customers_for_dropdown, 
                         account_types=demo_account_types)

@app.route('/open_account', methods=['POST'])
def open_account():
    """Open new account (demo)"""
    try:
        account_id = len(demo_accounts) + 100001
        flash(f'Account opened successfully with ID: {account_id}', 'success')
    except Exception as e:
        flash(f'Error opening account: {str(e)}', 'error')
    
    return redirect(url_for('accounts'))

@app.route('/transactions')
def transactions():
    """Transaction management page"""
    accounts_for_dropdown = [(a[0], f"{a[1]} ({a[2]})") for a in demo_accounts]
    return render_template('transactions.html', 
                         transactions=demo_transactions, 
                         accounts=accounts_for_dropdown)

@app.route('/deposit', methods=['POST'])
def deposit():
    """Process deposit (demo)"""
    try:
        amount = request.form['amount']
        flash(f'Deposit of ₹{amount} processed successfully', 'success')
    except Exception as e:
        flash(f'Error processing deposit: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/withdraw', methods=['POST'])
def withdraw():
    """Process withdrawal (demo)"""
    try:
        amount = request.form['amount']
        flash(f'Withdrawal of ₹{amount} processed successfully', 'success')
    except Exception as e:
        flash(f'Error processing withdrawal: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/transfer', methods=['POST'])
def transfer():
    """Process fund transfer (demo)"""
    try:
        amount = request.form['amount']
        flash(f'Transfer of ₹{amount} processed successfully', 'success')
    except Exception as e:
        flash(f'Error processing transfer: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/loans')
def loans():
    """Loan management page"""
    customers_for_dropdown = [(c[0], f"{c[1]} {c[2]}") for c in demo_customers]
    return render_template('loans.html', loans=demo_loans, customers=customers_for_dropdown)

@app.route('/apply_loan', methods=['POST'])
def apply_loan():
    """Apply for loan (demo)"""
    try:
        loan_id = len(demo_loans) + 10001
        flash(f'Loan application submitted with ID: {loan_id}', 'success')
    except Exception as e:
        flash(f'Error applying for loan: {str(e)}', 'error')
    
    return redirect(url_for('loans'))

@app.route('/reports')
def reports():
    """Reports page"""
    return render_template('reports.html')

@app.route('/api/account_balance/<int:account_id>')
def get_account_balance(account_id):
    """API endpoint to get account balance (demo)"""
    # Find account in demo data
    for account in demo_accounts:
        if account[0] == account_id:
            return jsonify({'balance': account[4]})
    
    return jsonify({'error': 'Account not found'}), 404

if __name__ == '__main__':
    print("🏦 Dubey's Banking Management System - Demo Mode")
    print("=" * 50)
    print("✅ Flask application starting...")
    print("✅ Demo data loaded")
    print("🌐 Access the application at: http://localhost:5000")
    print("📝 Note: This is a demo version with sample data")
    print("   For full functionality, connect to Oracle database")
    print()
    
    app.run(debug=True, host='0.0.0.0', port=5000)