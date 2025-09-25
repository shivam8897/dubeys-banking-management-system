"""
Dubey's Banking Management System - Flask Web Application
Author: Shivam Dubey
Description: Web interface for banking operations
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
import cx_Oracle
import os
from datetime import datetime
import logging
from config import config

# Create Flask app with configuration
def create_app(config_name=None):
    app = Flask(__name__)
    
    # Load configuration
    config_name = config_name or os.environ.get('FLASK_ENV', 'development')
    app.config.from_object(config[config_name])
    
    return app

app = create_app()

# Database configuration from config class
DB_CONFIG = app.config['Config'].get_db_config() if hasattr(app.config, 'Config') else {
    'user': os.environ.get('DB_USER', 'your_username'),
    'password': os.environ.get('DB_PASSWORD', 'your_password'),
    'dsn': f"{os.environ.get('DB_HOST', 'localhost')}:{os.environ.get('DB_PORT', '1521')}/{os.environ.get('DB_SERVICE', 'XE')}"
}

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def get_db_connection():
    """Get database connection"""
    try:
        connection = cx_Oracle.connect(**DB_CONFIG)
        return connection
    except cx_Oracle.Error as e:
        logger.error(f"Database connection error: {e}")
        return None

@app.route('/')
def index():
    """Home page"""
    return render_template('index.html')

@app.route('/customers')
def customers():
    """Customer management page"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return render_template('customers.html', customers=[])
    
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT customer_id, first_name, last_name, email, phone, 
                   address, date_of_birth, created_date, status
            FROM CUSTOMERS 
            ORDER BY created_date DESC
        """)
        customers = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return render_template('customers.html', customers=customers)
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching customers: {e}")
        flash('Error fetching customer data', 'error')
        return render_template('customers.html', customers=[])

@app.route('/add_customer', methods=['POST'])
def add_customer():
    """Add new customer"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('customers'))
    
    try:
        cursor = conn.cursor()
        customer_id = cursor.var(cx_Oracle.NUMBER)
        
        cursor.callproc('pkg_customer_mgmt.add_customer', [
            request.form['first_name'],
            request.form['last_name'],
            request.form['email'],
            request.form['phone'],
            request.form['address'],
            datetime.strptime(request.form['date_of_birth'], '%Y-%m-%d'),
            customer_id
        ])
        
        cursor.close()
        conn.close()
        
        flash(f'Customer added successfully with ID: {customer_id.getvalue()}', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error adding customer: {e}")
        flash(f'Error adding customer: {str(e)}', 'error')
    
    return redirect(url_for('customers'))

@app.route('/accounts')
def accounts():
    """Account management page"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return render_template('accounts.html', accounts=[], customers=[], account_types=[])
    
    try:
        cursor = conn.cursor()
        
        # Get accounts with customer and type information
        cursor.execute("""
            SELECT a.account_id, a.account_number, 
                   c.first_name || ' ' || c.last_name as customer_name,
                   at.type_name, a.balance, a.opened_date, a.status
            FROM ACCOUNTS a
            JOIN CUSTOMERS c ON a.customer_id = c.customer_id
            JOIN ACCOUNT_TYPES at ON a.account_type_id = at.type_id
            ORDER BY a.opened_date DESC
        """)
        accounts = cursor.fetchall()
        
        # Get customers for dropdown
        cursor.execute("SELECT customer_id, first_name || ' ' || last_name as name FROM CUSTOMERS WHERE status = 'ACTIVE'")
        customers = cursor.fetchall()
        
        # Get account types
        cursor.execute("SELECT type_id, type_name, min_balance FROM ACCOUNT_TYPES")
        account_types = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return render_template('accounts.html', accounts=accounts, customers=customers, account_types=account_types)
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching accounts: {e}")
        flash('Error fetching account data', 'error')
        return render_template('accounts.html', accounts=[], customers=[], account_types=[])

@app.route('/open_account', methods=['POST'])
def open_account():
    """Open new account"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('accounts'))
    
    try:
        cursor = conn.cursor()
        account_id = cursor.var(cx_Oracle.NUMBER)
        
        cursor.callproc('pkg_account_mgmt.open_account', [
            int(request.form['customer_id']),
            int(request.form['account_type_id']),
            float(request.form['initial_deposit']),
            account_id
        ])
        
        cursor.close()
        conn.close()
        
        flash(f'Account opened successfully with ID: {account_id.getvalue()}', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error opening account: {e}")
        flash(f'Error opening account: {str(e)}', 'error')
    
    return redirect(url_for('accounts'))

@app.route('/transactions')
def transactions():
    """Transaction management page"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return render_template('transactions.html', transactions=[], accounts=[])
    
    try:
        cursor = conn.cursor()
        
        # Get recent transactions
        cursor.execute("""
            SELECT th.transaction_id, th.account_id, a.account_number,
                   th.transaction_type, th.amount, th.balance_after,
                   th.description, th.transaction_date
            FROM TRANSACTION_HISTORY th
            JOIN ACCOUNTS a ON th.account_id = a.account_id
            ORDER BY th.transaction_date DESC
            FETCH FIRST 50 ROWS ONLY
        """)
        transactions = cursor.fetchall()
        
        # Get active accounts for dropdowns
        cursor.execute("""
            SELECT a.account_id, a.account_number || ' (' || c.first_name || ' ' || c.last_name || ')' as display_name
            FROM ACCOUNTS a
            JOIN CUSTOMERS c ON a.customer_id = c.customer_id
            WHERE a.status = 'ACTIVE'
            ORDER BY a.account_number
        """)
        accounts = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return render_template('transactions.html', transactions=transactions, accounts=accounts)
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching transactions: {e}")
        flash('Error fetching transaction data', 'error')
        return render_template('transactions.html', transactions=[], accounts=[])

@app.route('/deposit', methods=['POST'])
def deposit():
    """Process deposit"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('transactions'))
    
    try:
        cursor = conn.cursor()
        cursor.callproc('pkg_account_mgmt.deposit_money', [
            int(request.form['account_id']),
            float(request.form['amount']),
            request.form['description']
        ])
        
        cursor.close()
        conn.close()
        
        flash('Deposit processed successfully', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error processing deposit: {e}")
        flash(f'Error processing deposit: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/withdraw', methods=['POST'])
def withdraw():
    """Process withdrawal"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('transactions'))
    
    try:
        cursor = conn.cursor()
        cursor.callproc('pkg_account_mgmt.withdraw_money', [
            int(request.form['account_id']),
            float(request.form['amount']),
            request.form['description']
        ])
        
        cursor.close()
        conn.close()
        
        flash('Withdrawal processed successfully', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error processing withdrawal: {e}")
        flash(f'Error processing withdrawal: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/transfer', methods=['POST'])
def transfer():
    """Process fund transfer"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('transactions'))
    
    try:
        cursor = conn.cursor()
        cursor.callproc('pkg_account_mgmt.transfer_funds', [
            int(request.form['from_account_id']),
            int(request.form['to_account_id']),
            float(request.form['amount']),
            request.form['description']
        ])
        
        cursor.close()
        conn.close()
        
        flash('Transfer processed successfully', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error processing transfer: {e}")
        flash(f'Error processing transfer: {str(e)}', 'error')
    
    return redirect(url_for('transactions'))

@app.route('/loans')
def loans():
    """Loan management page"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return render_template('loans.html', loans=[], customers=[])
    
    try:
        cursor = conn.cursor()
        
        # Get loans with customer information
        cursor.execute("""
            SELECT l.loan_id, c.first_name || ' ' || c.last_name as customer_name,
                   l.loan_type, l.principal_amount, l.interest_rate, l.tenure_months,
                   l.emi_amount, l.outstanding_balance, l.application_date, l.status
            FROM LOANS l
            JOIN CUSTOMERS c ON l.customer_id = c.customer_id
            ORDER BY l.application_date DESC
        """)
        loans = cursor.fetchall()
        
        # Get customers for dropdown
        cursor.execute("SELECT customer_id, first_name || ' ' || last_name as name FROM CUSTOMERS WHERE status = 'ACTIVE'")
        customers = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return render_template('loans.html', loans=loans, customers=customers)
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching loans: {e}")
        flash('Error fetching loan data', 'error')
        return render_template('loans.html', loans=[], customers=[])

@app.route('/apply_loan', methods=['POST'])
def apply_loan():
    """Apply for loan"""
    conn = get_db_connection()
    if not conn:
        flash('Database connection failed', 'error')
        return redirect(url_for('loans'))
    
    try:
        cursor = conn.cursor()
        loan_id = cursor.var(cx_Oracle.NUMBER)
        
        cursor.callproc('pkg_loan_mgmt.apply_loan', [
            int(request.form['customer_id']),
            request.form['loan_type'],
            float(request.form['principal_amount']),
            float(request.form['interest_rate']),
            int(request.form['tenure_months']),
            loan_id
        ])
        
        cursor.close()
        conn.close()
        
        flash(f'Loan application submitted with ID: {loan_id.getvalue()}', 'success')
    except cx_Oracle.Error as e:
        logger.error(f"Error applying for loan: {e}")
        flash(f'Error applying for loan: {str(e)}', 'error')
    
    return redirect(url_for('loans'))

@app.route('/reports')
def reports():
    """Reports page"""
    return render_template('reports.html')

@app.route('/api/account_balance/<int:account_id>')
def get_account_balance(account_id):
    """API endpoint to get account balance"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor()
        balance = cursor.callfunc('get_account_balance', cx_Oracle.NUMBER, [account_id])
        cursor.close()
        conn.close()
        
        return jsonify({'balance': float(balance)})
    except cx_Oracle.Error as e:
        logger.error(f"Error getting balance: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/api/recent_transactions')
def get_recent_transactions():
    """API endpoint to get recent transactions"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT th.transaction_id, th.account_id, a.account_number,
                   th.transaction_type, th.amount, th.balance_after,
                   th.description, th.transaction_date
            FROM TRANSACTION_HISTORY th
            JOIN ACCOUNTS a ON th.account_id = a.account_id
            ORDER BY th.transaction_date DESC
            FETCH FIRST 20 ROWS ONLY
        """)
        transactions = cursor.fetchall()
        cursor.close()
        conn.close()
        
        # Convert to list of dictionaries
        transaction_list = []
        for t in transactions:
            transaction_list.append({
                'id': t[0],
                'account_id': t[1],
                'account_number': t[2],
                'type': t[3],
                'amount': float(t[4]),
                'balance_after': float(t[5]),
                'description': t[6],
                'date': t[7].isoformat() if t[7] else None
            })
        
        return jsonify({'transactions': transaction_list})
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching transactions: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/api/dashboard_stats')
def get_dashboard_stats():
    """API endpoint to get dashboard statistics"""
    conn = get_db_connection()
    if not conn:
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cursor = conn.cursor()
        
        # Get customer count
        cursor.execute("SELECT COUNT(*) FROM CUSTOMERS WHERE status = 'ACTIVE'")
        customer_count = cursor.fetchone()[0]
        
        # Get account count
        cursor.execute("SELECT COUNT(*) FROM ACCOUNTS WHERE status = 'ACTIVE'")
        account_count = cursor.fetchone()[0]
        
        # Get total balance
        cursor.execute("SELECT SUM(balance) FROM ACCOUNTS WHERE status = 'ACTIVE'")
        total_balance = cursor.fetchone()[0] or 0
        
        # Get active loans count
        cursor.execute("SELECT COUNT(*) FROM LOANS WHERE status IN ('APPROVED', 'DISBURSED')")
        loan_count = cursor.fetchone()[0]
        
        # Get today's transactions
        cursor.execute("""
            SELECT COUNT(*) FROM TRANSACTION_HISTORY 
            WHERE transaction_date >= TRUNC(SYSDATE)
        """)
        daily_transactions = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
        
        return jsonify({
            'customers': customer_count,
            'accounts': account_count,
            'total_balance': float(total_balance),
            'active_loans': loan_count,
            'daily_transactions': daily_transactions
        })
    except cx_Oracle.Error as e:
        logger.error(f"Error fetching dashboard stats: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/api/calculate_emi')
def calculate_emi_api():
    """API endpoint to calculate EMI"""
    try:
        principal = float(request.args.get('principal', 0))
        rate = float(request.args.get('rate', 0))
        tenure = int(request.args.get('tenure', 0))
        
        if principal <= 0 or rate <= 0 or tenure <= 0:
            return jsonify({'error': 'Invalid parameters'}), 400
        
        monthly_rate = rate / (12 * 100)
        emi = principal * monthly_rate * (1 + monthly_rate) ** tenure / ((1 + monthly_rate) ** tenure - 1)
        total_amount = emi * tenure
        total_interest = total_amount - principal
        
        return jsonify({
            'emi': round(emi, 2),
            'total_amount': round(total_amount, 2),
            'total_interest': round(total_interest, 2)
        })
    except (ValueError, TypeError) as e:
        return jsonify({'error': 'Invalid input parameters'}), 400

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)