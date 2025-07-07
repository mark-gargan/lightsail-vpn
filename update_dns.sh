#!/bin/bash

# DNSimple DNS Update Script
# Updates DNS A record with current instance IP

set -e

# Configuration - modify these for your domain
DOMAIN="${DNS_DOMAIN:-your-domain.com}"
RECORD_NAME="${DNS_RECORD_NAME:-vpn}"
RECORD_TYPE="A"
TTL=300

# Get current public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Failed to get public IP"
    exit 1
fi

echo "🌐 Current public IP: $PUBLIC_IP"

# Check if DNSimple credentials are available
if [ -z "$DNSIMPLE_TOKEN" ] || [ -z "$DNSIMPLE_ACCOUNT_ID" ]; then
    echo "❌ DNSimple credentials not found"
    echo "Please set DNSIMPLE_TOKEN and DNSIMPLE_ACCOUNT_ID environment variables"
    exit 1
fi

# Get existing record
echo "🔍 Checking existing DNS record..."
EXISTING_RECORD=$(curl -s -H "Authorization: Bearer $DNSIMPLE_TOKEN" \
    "https://api.dnsimple.com/v2/$DNSIMPLE_ACCOUNT_ID/zones/$DOMAIN/records" \
    | jq -r ".data[] | select(.name == \"$RECORD_NAME\" and .type == \"$RECORD_TYPE\") | .id")

if [ -z "$EXISTING_RECORD" ] || [ "$EXISTING_RECORD" == "null" ]; then
    echo "📝 Creating new DNS record..."
    curl -X POST \
        -H "Authorization: Bearer $DNSIMPLE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$RECORD_NAME\",\"type\":\"$RECORD_TYPE\",\"content\":\"$PUBLIC_IP\",\"ttl\":$TTL}" \
        "https://api.dnsimple.com/v2/$DNSIMPLE_ACCOUNT_ID/zones/$DOMAIN/records"
    echo "✅ DNS record created"
else
    echo "🔄 Updating existing DNS record (ID: $EXISTING_RECORD)..."
    curl -X PATCH \
        -H "Authorization: Bearer $DNSIMPLE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"$PUBLIC_IP\",\"ttl\":$TTL}" \
        "https://api.dnsimple.com/v2/$DNSIMPLE_ACCOUNT_ID/zones/$DOMAIN/records/$EXISTING_RECORD"
    echo "✅ DNS record updated"
fi

echo "🎉 DNS update completed: $RECORD_NAME.$DOMAIN -> $PUBLIC_IP"