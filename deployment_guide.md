# Banking Management System - Deployment Guide

## 🚀 Production Deployment Guide

### Prerequisites

#### Database Requirements
- Oracle Database 12c or higher (recommended: 19c)
- Minimum 4GB RAM allocated to Oracle
- At least 10GB free disk space
- Oracle Enterprise Manager (optional, for monitoring)

#### Application Server Requirements
- Python 3.8+ 
- 2GB RAM minimum
- Web server (Apache/Nginx) for production
- SSL certificate for HTTPS

### 1. Database Deployment

#### Step 1: Create Database User
```sql
-- Connect as SYSDBA
CREATE USER bms_user IDENTIFIED BY "SecurePassword123!";
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE MATERIALIZED VIEW TO bms_user;
GRANT CREATE JOB TO bms_user;
GRANT EXECUTE ON DBMS_SCHEDULER TO bms_user;
GRANT EXECUTE ON DBMS_STATS TO bms_user;
GRANT EXECUTE ON DBMS_MVIEW TO bms_user;

-- Grant tablespace quota
ALTER USER bms_user QUOTA UNLIMITED ON USERS;
```

#### Step 2: Deploy Database Schema
```bash
# Connect as bms_user
sqlplus bms_user/SecurePassword123!@your_database

# Run setup script
@setup_database.sql

# Optional: Performance tuning
@SQL/performance_tuning.sql

# Optional: Scheduler jobs
@SQL/scheduler_jobs.sql
```

#### Step 3: Database Security
```sql
-- Create read-only user for reporting
CREATE USER bms_readonly IDENTIFIED BY "ReadOnlyPass123!";
GRANT CONNECT TO bms_readonly;
GRANT SELECT ON bms_user.CUSTOMERS TO bms_readonly;
GRANT SELECT ON bms_user.ACCOUNTS TO bms_readonly;
GRANT SELECT ON bms_user.TRANSACTION_HISTORY TO bms_readonly;
GRANT SELECT ON bms_user.LOANS TO bms_readonly;
GRANT SELECT ON bms_user.LOAN_PAYMENTS TO bms_readonly;

-- Enable auditing
AUDIT SELECT, INSERT, UPDATE, DELETE ON bms_user.CUSTOMERS;
AUDIT SELECT, INSERT, UPDATE, DELETE ON bms_user.ACCOUNTS;
AUDIT SELECT, INSERT, UPDATE, DELETE ON bms_user.TRANSACTION_HISTORY;
```

### 2. Application Deployment

#### Step 1: Server Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and dependencies
sudo apt install python3 python3-pip python3-venv nginx -y

# Install Oracle Instant Client
wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linuxx64.zip
unzip instantclient-basiclite-linuxx64.zip
sudo mv instantclient_* /opt/oracle/
echo 'export LD_LIBRARY_PATH=/opt/oracle/instantclient_21_1:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

#### Step 2: Application Setup
```bash
# Create application directory
sudo mkdir -p /opt/bms
sudo chown $USER:$USER /opt/bms
cd /opt/bms

# Clone or copy application files
# (Copy your Banking-Management-System directory here)

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r UI/requirements.txt
pip install gunicorn
```

#### Step 3: Configuration
```bash
# Create production environment file
cp UI/.env.example UI/.env

# Edit with production values
nano UI/.env
```

```env
# Production Environment Variables
SECRET_KEY=your-super-secret-production-key-here
FLASK_ENV=production

# Database Configuration
DB_USER=bms_user
DB_PASSWORD=SecurePassword123!
DB_HOST=your-db-server.com
DB_PORT=1521
DB_SERVICE=ORCL

# Application Settings
ITEMS_PER_PAGE=50
MAX_TRANSACTION_AMOUNT=10000000
SESSION_TIMEOUT=1800
```

#### Step 4: Create Systemd Service
```bash
sudo nano /etc/systemd/system/bms.service
```

```ini
[Unit]
Description=Banking Management System
After=network.target

[Service]
User=bms
Group=bms
WorkingDirectory=/opt/bms
Environment=PATH=/opt/bms/venv/bin
ExecStart=/opt/bms/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 UI.app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Create bms user
sudo useradd -r -s /bin/false bms
sudo chown -R bms:bms /opt/bms

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable bms
sudo systemctl start bms
```

#### Step 5: Nginx Configuration
```bash
sudo nano /etc/nginx/sites-available/bms
```

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL Configuration
    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static files
    location /static {
        alias /opt/bms/UI/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/bms /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 3. Security Configuration

#### Database Security
```sql
-- Enable Oracle Database Vault (if available)
-- Configure fine-grained access control
-- Set up database encryption

-- Regular security maintenance
CREATE OR REPLACE PROCEDURE security_audit AS
BEGIN
    -- Log security events
    INSERT INTO LOAN_AUDIT (
        audit_id, loan_id, old_status, new_status,
        changed_by, change_date, remarks
    ) VALUES (
        seq_audit_id.NEXTVAL, 0, 'SECURITY', 'AUDIT',
        'SYSTEM', SYSDATE, 'Daily security audit completed'
    );
    COMMIT;
END;
/
```

#### Application Security
```bash
# Set up firewall
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# Set up fail2ban
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Monitoring and Backup

#### Database Backup
```bash
# Create backup script
sudo nano /opt/bms/backup_db.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/opt/backups/bms"
DATE=$(date +%Y%m%d_%H%M%S)
ORACLE_SID=ORCL

mkdir -p $BACKUP_DIR

# Export schema
expdp bms_user/SecurePassword123! \
    directory=DATA_PUMP_DIR \
    dumpfile=bms_backup_$DATE.dmp \
    logfile=bms_backup_$DATE.log \
    schemas=bms_user

# Compress backup
gzip $BACKUP_DIR/bms_backup_$DATE.dmp

# Remove backups older than 30 days
find $BACKUP_DIR -name "*.gz" -mtime +30 -delete
```

#### Application Monitoring
```bash
# Install monitoring tools
pip install psutil

# Create monitoring script
nano /opt/bms/monitor.py
```

```python
#!/usr/bin/env python3
import psutil
import cx_Oracle
import smtplib
from email.mime.text import MIMEText
from datetime import datetime

def check_system_health():
    # Check CPU, memory, disk usage
    cpu_percent = psutil.cpu_percent(interval=1)
    memory_percent = psutil.virtual_memory().percent
    disk_percent = psutil.disk_usage('/').percent
    
    # Check database connectivity
    try:
        conn = cx_Oracle.connect('bms_user/SecurePassword123!@localhost:1521/ORCL')
        cursor = conn.cursor()
        cursor.execute('SELECT 1 FROM DUAL')
        db_status = 'OK'
        conn.close()
    except:
        db_status = 'ERROR'
    
    # Send alerts if thresholds exceeded
    if cpu_percent > 80 or memory_percent > 80 or disk_percent > 90 or db_status == 'ERROR':
        send_alert(f"System Alert: CPU:{cpu_percent}% MEM:{memory_percent}% DISK:{disk_percent}% DB:{db_status}")

def send_alert(message):
    # Configure email alerts
    pass

if __name__ == "__main__":
    check_system_health()
```

### 5. Performance Optimization

#### Database Tuning
```sql
-- Configure SGA and PGA
ALTER SYSTEM SET sga_target=2G SCOPE=SPFILE;
ALTER SYSTEM SET pga_aggregate_target=1G SCOPE=SPFILE;

-- Enable automatic memory management
ALTER SYSTEM SET memory_target=3G SCOPE=SPFILE;

-- Configure redo logs for performance
ALTER DATABASE ADD LOGFILE GROUP 4 '/path/to/redo04.log' SIZE 100M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/path/to/redo05.log' SIZE 100M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/path/to/redo06.log' SIZE 100M;
```

#### Application Tuning
```python
# Update UI/app.py for production
from flask import Flask
from werkzeug.middleware.proxy_fix import ProxyFix

app = Flask(__name__)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# Enable connection pooling
import cx_Oracle
cx_Oracle.init_oracle_client(lib_dir="/opt/oracle/instantclient_21_1")

# Configure session pool
pool = cx_Oracle.SessionPool(
    user="bms_user",
    password="SecurePassword123!",
    dsn="localhost:1521/ORCL",
    min=2,
    max=10,
    increment=1
)
```

### 6. Go-Live Checklist

- [ ] Database schema deployed and tested
- [ ] Sample data removed (keep only reference data)
- [ ] All security configurations applied
- [ ] SSL certificate installed and configured
- [ ] Backup procedures tested
- [ ] Monitoring systems active
- [ ] Performance baselines established
- [ ] User training completed
- [ ] Documentation updated
- [ ] Disaster recovery plan tested

### 7. Post-Deployment

#### Daily Tasks
- Monitor system performance
- Check backup completion
- Review security logs
- Verify scheduler job execution

#### Weekly Tasks
- Update database statistics
- Review system capacity
- Test backup restoration
- Security patch assessment

#### Monthly Tasks
- Performance tuning review
- Capacity planning
- Security audit
- Disaster recovery testing

## Support and Maintenance

For ongoing support:
1. Monitor application logs: `/var/log/nginx/` and systemd logs
2. Database monitoring: Oracle Enterprise Manager or custom scripts
3. Regular security updates for OS and application dependencies
4. Performance monitoring and optimization

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   - Check Oracle listener status
   - Verify network connectivity
   - Check user privileges

2. **Application Performance**
   - Monitor database query performance
   - Check system resources
   - Review application logs

3. **Security Concerns**
   - Regular security audits
   - Monitor failed login attempts
   - Keep systems updated

For detailed troubleshooting, refer to the system logs and Oracle documentation.