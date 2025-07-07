#!/bin/bash

# Route53 DNS Update Script
# Updates DNS A record with current instance IP using AWS Route53

set -e

# Configuration - modify these for your domain
HOSTED_ZONE_ID="${ROUTE53_HOSTED_ZONE_ID}"
DOMAIN_NAME="${DNS_DOMAIN:-your-domain.com}"
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

# Check if Route53 configuration is available
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "❌ ROUTE53_HOSTED_ZONE_ID environment variable not set"
    echo "Please set ROUTE53_HOSTED_ZONE_ID to your Route53 hosted zone ID"
    exit 1
fi

# Construct full domain name
FULL_DOMAIN_NAME="$RECORD_NAME.$DOMAIN_NAME"

echo "🔍 Updating Route53 record: $FULL_DOMAIN_NAME"

# Create change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$FULL_DOMAIN_NAME",
                "Type": "$RECORD_TYPE",
                "TTL": $TTL,
                "ResourceRecords": [
                    {
                        "Value": "$PUBLIC_IP"
                    }
                ]
            }
        }
    ]
}
EOF
)

# Submit change to Route53
echo "🔄 Submitting DNS update to Route53..."
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch "$CHANGE_BATCH" \
    --query 'ChangeInfo.Id' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ DNS update submitted successfully"
    echo "📋 Change ID: $CHANGE_ID"
    echo "🎉 DNS update completed: $FULL_DOMAIN_NAME -> $PUBLIC_IP"
    
    # Optionally wait for change to propagate
    if [ "${WAIT_FOR_PROPAGATION:-false}" = "true" ]; then
        echo "⏳ Waiting for DNS change to propagate..."
        aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"
        echo "✅ DNS change has propagated"
    fi
else
    echo "❌ Failed to update Route53 DNS record"
    exit 1
fi