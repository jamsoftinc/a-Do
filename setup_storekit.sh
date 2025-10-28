#!/bin/bash

# StoreKit Configuration Setup Script
# This script helps configure the StoreKit configuration file for testing

echo "🔧 Setting up StoreKit Configuration for a-do"
echo ""

# Check if Configuration.storekit exists
if [ -f "a-do/Configuration.storekit" ]; then
    echo "✅ Configuration.storekit file found"
else
    echo "❌ Configuration.storekit file not found"
    exit 1
fi

echo ""
echo "📋 Manual Steps Required:"
echo ""
echo "1. Open a-do.xcodeproj in Xcode"
echo "2. Select the 'a-do' target in the project navigator"
echo "3. Go to the 'Signing & Capabilities' tab"
echo "4. Scroll down and click the '+' button to add a capability"
echo "5. Search for and add 'StoreKit Configuration'"
echo "6. In the StoreKit Configuration section, select 'Configuration.storekit'"
echo ""
echo "7. To test in simulator:"
echo "   - Run the app in the iOS Simulator"
echo "   - Go to Device > StoreKit Configuration"
echo "   - Select 'a-do-subscriptions'"
echo "   - Now you can test purchases and subscriptions!"
echo ""
echo "🎯 Testing Features:"
echo "   - Free trial will work (7 days)"
echo "   - Monthly subscription: $2.99"
echo "   - Annual subscription: $19.99"
echo "   - All Pro features will be accessible during trial/purchase"
echo ""
echo "💡 Pro Tips:"
echo "   - Use 'Device > StoreKit Configuration' to manage subscriptions"
echo "   - You can simulate subscription renewals, cancellations, etc."
echo "   - Test different subscription states (active, expired, etc.)"
