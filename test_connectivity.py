#!/usr/bin/env python3
"""
Quick connectivity test for iPhone deployment
Run this while your Flask server is running to verify everything works
"""

import requests
import json
import sys

def test_endpoint(url, method='GET', data=None, description=""):
    """Test a single endpoint"""
    try:
        print(f"\n{'='*60}")
        print(f"Testing: {description}")
        print(f"URL: {url}")
        print(f"Method: {method}")
        
        if method == 'GET':
            response = requests.get(url, timeout=5)
        else:
            response = requests.post(url, json=data, timeout=5)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ SUCCESS")
            try:
                print("Response:", json.dumps(response.json(), indent=2))
            except:
                print("Response:", response.text)
            return True
        else:
            print(f"❌ FAILED - Status {response.status_code}")
            print("Response:", response.text)
            return False
            
    except requests.exceptions.ConnectionError:
        print("❌ FAILED - Cannot connect to server")
        print("   Make sure Flask server is running!")
        return False
    except requests.exceptions.Timeout:
        print("❌ FAILED - Request timed out")
        return False
    except Exception as e:
        print(f"❌ FAILED - {str(e)}")
        return False

def main():
    print("""
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        Backend Connectivity Test                           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
    """)
    
    BASE_URL = "http://192.168.1.54:5001"
    
    print(f"\n🎯 Testing backend at: {BASE_URL}")
    print("📝 Make sure your Flask server is running first!")
    
    input("\nPress Enter to start tests...")
    
    results = []
    
    # Test 1: Health check
    results.append(test_endpoint(
        f"{BASE_URL}/health",
        description="Health Check Endpoint"
    ))
    
    # Test 2: Create test user
    print("\n\nCreating a test user...")
    test_user_data = {
        "username": "testuser",
        "email": "test@example.com",
        "password": "testpass123"
    }
    
    success = test_endpoint(
        f"{BASE_URL}/create-user",
        method='POST',
        data=test_user_data,
        description="Create User Endpoint"
    )
    results.append(success)
    
    # Test 3: Login (optional, depends on if user already exists)
    if not success:
        print("\n\nUser might already exist, trying login...")
        login_data = {
            "email": "test@example.com",
            "password": "testpass123"
        }
        results.append(test_endpoint(
            f"{BASE_URL}/login",
            method='POST',
            data=login_data,
            description="Login Endpoint"
        ))
    
    # Summary
    print(f"\n\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    passed = sum(results)
    total = len(results)
    
    print(f"\nTests passed: {passed}/{total}")
    
    if passed == total:
        print("\n✅ All tests passed! Your backend is ready for iPhone deployment!")
        print("\n📱 Next steps:")
        print("   1. Open informed.xcodeproj in Xcode")
        print("   2. Connect your iPhone")
        print("   3. Select your iPhone as the target device")
        print("   4. Press Run (▶️)")
    else:
        print("\n⚠️  Some tests failed. Please check:")
        print("   1. Is Flask server running? (python3 app.py)")
        print("   2. Is the IP address correct? (192.168.1.163)")
        print("   3. Check the Flask console for errors")
    
    print(f"\n{'='*60}\n")

if __name__ == "__main__":
    try:
        import requests
    except ImportError:
        print("❌ Error: 'requests' library not installed")
        print("Install it with: pip3 install requests")
        sys.exit(1)
    
    main()
