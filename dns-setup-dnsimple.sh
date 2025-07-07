#!/bin/bash

# Setup DNS update for Lightsail instance

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <DNSIMPLE_TOKEN> <DNSIMPLE_ACCOUNT_ID>"
    echo "Example: $0 your_token_here 12345"
    exit 1
fi

DNSIMPLE_TOKEN="$1"
DNSIMPLE_ACCOUNT_ID="$2"

# Get Lightsail server IP
SERVER_IP=$(terraform output -raw vpn_server_ip 2>/dev/null)

if [ -z "$SERVER_IP" ]; then
    echo "❌ Could not get server IP from Terraform output"
    echo "Make sure you've deployed the Lightsail instance first"
    exit 1
fi

echo "🚀 Setting up DNS update for Lightsail VPN server..."
echo "🌐 Server IP: $SERVER_IP"

# Copy the DNS update script to the server
scp -o StrictHostKeyChecking=no update_dns.sh ubuntu@$SERVER_IP:/tmp/

# Set up the script on the server
ssh -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << EOF
    # Create environment file for credentials
    sudo mkdir -p /etc/systemd/system/environment.d
    sudo tee /etc/systemd/system/environment.d/dnsimple.conf > /dev/null << EOL
DNSIMPLE_TOKEN=$DNSIMPLE_TOKEN
DNSIMPLE_ACCOUNT_ID=$DNSIMPLE_ACCOUNT_ID
EOL

    # Copy script to proper location
    sudo cp /tmp/update_dns.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/update_dns.sh

    # Create systemd service for DNS updates
    sudo tee /etc/systemd/system/dns-update.service > /dev/null << EOL
[Unit]
Description=Update DNSimple DNS record for VPN
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/systemd/system/environment.d/dnsimple.conf
ExecStart=/usr/local/bin/update_dns.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

    # Create timer for periodic updates
    sudo tee /etc/systemd/system/dns-update.timer > /dev/null << EOL
[Unit]
Description=Update VPN DNS record every 5 minutes
Requires=dns-update.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOL

    # Enable and start the services
    sudo systemctl daemon-reload
    sudo systemctl enable dns-update.timer
    sudo systemctl start dns-update.timer
    sudo systemctl enable dns-update.service

    # Run the update immediately
    sudo systemctl start dns-update.service

    # Clean up
    rm /tmp/update_dns.sh
EOF

echo "✅ DNS update configured for Lightsail VPN"
echo "🔄 DNS will update automatically every 5 minutes"
echo "📋 Your DNS record will point to: $SERVER_IP"
echo ""
echo "🔧 To check DNS update status:"
echo "   ssh ubuntu@$SERVER_IP 'sudo systemctl status dns-update.timer'"
echo "   ssh ubuntu@$SERVER_IP 'sudo journalctl -u dns-update.service'"

# Update the client config to use DNS name
if [ -f "client.ovpn" ]; then
    echo "🔄 Updating client config to use DNS name..."
    echo "Please manually update client.ovpn to use your domain name instead of IP"
    echo "Example: Change 'remote $SERVER_IP 1194' to 'remote vpn.yourdomain.com 1194'"
fi