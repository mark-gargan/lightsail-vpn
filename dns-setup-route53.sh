#!/bin/bash

# Setup Route53 DNS update for Lightsail instance

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <HOSTED_ZONE_ID> <DOMAIN_NAME> [RECORD_NAME]"
    echo ""
    echo "Parameters:"
    echo "  HOSTED_ZONE_ID  - Your Route53 hosted zone ID (e.g., Z1234567890ABC)"
    echo "  DOMAIN_NAME     - Your domain name (e.g., example.com)"
    echo "  RECORD_NAME     - DNS record name (optional, defaults to 'vpn')"
    echo ""
    echo "Examples:"
    echo "  $0 Z1234567890ABC example.com"
    echo "  $0 Z1234567890ABC example.com vpn-uk"
    echo ""
    echo "This will create/update: [RECORD_NAME].[DOMAIN_NAME] -> server IP"
    exit 1
fi

HOSTED_ZONE_ID="$1"
DOMAIN_NAME="$2"
RECORD_NAME="${3:-vpn}"

# Get server IP from Terraform
SERVER_IP=$(terraform output -raw vpn_server_ip 2>/dev/null)

if [ -z "$SERVER_IP" ]; then
    echo "❌ Could not get server IP from Terraform output"
    echo "Make sure you've deployed the instance first"
    exit 1
fi

echo "🚀 Setting up Route53 DNS update..."
echo "🌐 Server IP: $SERVER_IP"
echo "📋 Domain: $RECORD_NAME.$DOMAIN_NAME"
echo "🏷️ Hosted Zone: $HOSTED_ZONE_ID"

# Verify AWS CLI has Route53 permissions
echo "🔍 Checking AWS Route53 permissions..."
if ! aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" >/dev/null 2>&1; then
    echo "❌ Cannot access hosted zone $HOSTED_ZONE_ID"
    echo "Please check:"
    echo "  1. Hosted zone ID is correct"
    echo "  2. AWS credentials have Route53 permissions"
    echo "  3. aws route53:GetHostedZone permission is granted"
    exit 1
fi

echo "✅ Route53 access verified"

# Copy the Route53 DNS update script to the server
scp -o StrictHostKeyChecking=no update_dns_route53.sh ubuntu@$SERVER_IP:/tmp/

# Set up the script on the server
ssh -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << EOF
    # Create environment file for Route53 configuration
    sudo mkdir -p /etc/systemd/system/environment.d
    sudo tee /etc/systemd/system/environment.d/route53.conf > /dev/null << EOL
ROUTE53_HOSTED_ZONE_ID=$HOSTED_ZONE_ID
DNS_DOMAIN=$DOMAIN_NAME
DNS_RECORD_NAME=$RECORD_NAME
WAIT_FOR_PROPAGATION=false
EOL

    # Copy script to proper location
    sudo cp /tmp/update_dns_route53.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/update_dns_route53.sh

    # Create systemd service for Route53 DNS updates
    sudo tee /etc/systemd/system/dns-update-route53.service > /dev/null << EOL
[Unit]
Description=Update Route53 DNS record for VPN
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/systemd/system/environment.d/route53.conf
ExecStart=/usr/local/bin/update_dns_route53.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

    # Create timer for periodic updates
    sudo tee /etc/systemd/system/dns-update-route53.timer > /dev/null << EOL
[Unit]
Description=Update Route53 DNS record every 5 minutes
Requires=dns-update-route53.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOL

    # Enable and start the services
    sudo systemctl daemon-reload
    sudo systemctl enable dns-update-route53.timer
    sudo systemctl start dns-update-route53.timer
    sudo systemctl enable dns-update-route53.service

    # Run the update immediately
    sudo systemctl start dns-update-route53.service

    # Clean up
    rm /tmp/update_dns_route53.sh
EOF

echo "✅ Route53 DNS update configured"
echo "🔄 DNS will update automatically every 5 minutes"
echo "📋 $RECORD_NAME.$DOMAIN_NAME will point to: $SERVER_IP"
echo ""
echo "🔧 To check DNS update status:"
echo "   ssh ubuntu@$SERVER_IP 'sudo systemctl status dns-update-route53.timer'"
echo "   ssh ubuntu@$SERVER_IP 'sudo journalctl -u dns-update-route53.service'"
echo ""
echo "🧪 To test DNS resolution:"
echo "   nslookup $RECORD_NAME.$DOMAIN_NAME"
echo "   dig $RECORD_NAME.$DOMAIN_NAME"

# Update the client config to use DNS name if it exists
if [ -f "client-$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_lightsail_instance") | .values.tags.CountryCode // "unknown"' 2>/dev/null).ovpn" ]; then
    COUNTRY_CODE=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_lightsail_instance") | .values.tags.CountryCode // "unknown"' 2>/dev/null)
    if [ "$COUNTRY_CODE" != "unknown" ] && [ -f "client-$COUNTRY_CODE.ovpn" ]; then
        echo "🔄 Updating client config to use DNS name..."
        sed -i.bak "s/remote $SERVER_IP 1194/remote $RECORD_NAME.$DOMAIN_NAME 1194/" "client-$COUNTRY_CODE.ovpn"
        echo "✅ Client config updated to use $RECORD_NAME.$DOMAIN_NAME"
    fi
fi