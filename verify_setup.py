#!/usr/bin/env python3
"""
Setup Verification Script for Informed iOS App
Checks if your backend is ready for physical iPhone deployment
"""

import socket
import sqlite3
import os
import sys

def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")

def print_check(check_name, passed, details=""):
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"{status} - {check_name}")
    if details:
        print(f"       {details}")

def get_local_ip():
    """Get the local IP address of this machine"""
    try:
        # Create a socket to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        return None

def check_databases():
    """Verify database files exist and have correct tables"""
    print_header("Database Check")
    
    # Check users.db
    users_db_exists = os.path.exists('users.db')
    print_check("users.db exists", users_db_exists)
    
    if users_db_exists:
        try:
            conn = sqlite3.connect('users.db')
            c = conn.cursor()
            
            # Check tables
            c.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in c.fetchall()]
            
            has_users = 'users' in tables
            has_sessions = 'sessions' in tables
            has_history = 'user_history' in tables
            
            print_check("users table exists", has_users)
            print_check("sessions table exists", has_sessions)
            print_check("user_history table exists", has_history)
            
            # Count records
            c.execute("SELECT COUNT(*) FROM users")
            user_count = c.fetchone()[0]
            print_check(f"User records: {user_count}", True, f"{user_count} users in database")
            
            conn.close()
        except Exception as e:
            print_check("users.db structure", False, str(e))
    
    # Check factcheck.db
    factcheck_db_exists = os.path.exists('factcheck.db')
    print_check("factcheck.db exists", factcheck_db_exists)
    
    if factcheck_db_exists:
        try:
            conn = sqlite3.connect('factcheck.db')
            c = conn.cursor()
            
            c.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in c.fetchall()]
            
            has_fact_checks = 'fact_checks' in tables
            print_check("fact_checks table exists", has_fact_checks)
            
            c.execute("SELECT COUNT(*) FROM fact_checks")
            fact_count = c.fetchone()[0]
            print_check(f"Fact check records: {fact_count}", True, f"{fact_count} fact checks in database")
            
            conn.close()
        except Exception as e:
            print_check("factcheck.db structure", False, str(e))

def check_network():
    """Check network configuration"""
    print_header("Network Configuration")
    
    local_ip = get_local_ip()
    if local_ip:
        print_check("Local IP detected", True, f"Your Mac's IP: {local_ip}")
        print(f"\n       📱 Update Config.swift to use:")
        print(f"       static let backendURL = \"http://{local_ip}:5001\"\n")
    else:
        print_check("Local IP detection", False, "Could not determine local IP")
    
    # Check if port 5001 is available
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(('', 5001))
        s.close()
        print_check("Port 5001 available", True)
    except OSError:
        print_check("Port 5001 available", False, "Port is already in use (server might be running)")

def check_dependencies():
    """Check required Python packages"""
    print_header("Python Dependencies")
    
    required_packages = [
        ('flask', 'Flask'),
        ('flask_cors', 'Flask-CORS'),
        ('sqlite3', 'SQLite3'),
    ]
    
    all_installed = True
    for package, display_name in required_packages:
        try:
            __import__(package)
            print_check(f"{display_name} installed", True)
        except ImportError:
            print_check(f"{display_name} installed", False, f"Install with: pip3 install {package}")
            all_installed = False
    
    return all_installed

def check_swift_config():
    """Check if Config.swift exists and show current backend URL"""
    print_header("iOS App Configuration")
    
    config_path = "informed/Config.swift"
    if os.path.exists(config_path):
        print_check("Config.swift found", True)
        
        with open(config_path, 'r') as f:
            content = f.read()
            # Extract backend URL
            for line in content.split('\n'):
                if 'backendURL' in line and '=' in line:
                    print(f"       Current setting: {line.strip()}")
                    break
    else:
        print_check("Config.swift found", False, f"Not found at {config_path}")

def print_next_steps():
    """Print next steps for user"""
    print_header("Next Steps")
    print("""
1. 📡 Ensure Mac and iPhone are on the same WiFi network
   
2. 🔧 Update Config.swift with your Mac's IP address (shown above)
   
3. 🚀 Start your Flask server:
   python3 app.py
   
4. 🧪 Test from iPhone Safari:
   Navigate to: http://YOUR_MAC_IP:5001/health
   Should see: {"status": "ok"}
   
5. 📱 Deploy to your iPhone:
   - Open Xcode
   - Connect iPhone via cable
   - Select your device
   - Press Run (▶️)
   
6. ✅ Trust certificate on iPhone (first time only):
   Settings → General → VPN & Device Management
    """)

def main():
    print("""
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   📱 Informed iOS App - Backend Verification Script        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
    """)
    
    # Run all checks
    deps_ok = check_dependencies()
    check_databases()
    check_network()
    check_swift_config()
    print_next_steps()
    
    print_header("Summary")
    if deps_ok:
        print("✅ Your backend is ready for physical iPhone deployment!")
    else:
        print("⚠️  Please install missing dependencies first")
    
    print("\n📖 For detailed instructions, see: PHYSICAL_IPHONE_DEPLOYMENT.md\n")

if __name__ == "__main__":
    main()
