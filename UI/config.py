"""
Banking Management System - Configuration
Author: BMS Development Team
Description: Configuration settings for the Flask application
"""

import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Config:
    """Base configuration class"""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Database Configuration
    DB_USER = os.environ.get('DB_USER') or 'your_username'
    DB_PASSWORD = os.environ.get('DB_PASSWORD') or 'your_password'
    DB_HOST = os.environ.get('DB_HOST') or 'localhost'
    DB_PORT = os.environ.get('DB_PORT') or '1521'
    DB_SERVICE = os.environ.get('DB_SERVICE') or 'XE'
    
    # Construct DSN
    DB_DSN = f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}"
    
    # Application Settings
    ITEMS_PER_PAGE = int(os.environ.get('ITEMS_PER_PAGE') or 20)
    MAX_TRANSACTION_AMOUNT = float(os.environ.get('MAX_TRANSACTION_AMOUNT') or 1000000)
    
    # Security Settings
    SESSION_TIMEOUT = int(os.environ.get('SESSION_TIMEOUT') or 3600)  # 1 hour
    
    @staticmethod
    def get_db_config():
        """Get database configuration dictionary"""
        return {
            'user': Config.DB_USER,
            'password': Config.DB_PASSWORD,
            'dsn': Config.DB_DSN
        }

class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    TESTING = False

class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    TESTING = False
    
    # Override with more secure settings for production
    SECRET_KEY = os.environ.get('SECRET_KEY')
    if not SECRET_KEY:
        raise ValueError("No SECRET_KEY set for production environment")

class TestingConfig(Config):
    """Testing configuration"""
    DEBUG = True
    TESTING = True
    
    # Use test database
    DB_SERVICE = os.environ.get('TEST_DB_SERVICE') or 'XETEST'

# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}