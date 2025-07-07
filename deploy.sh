#!/bin/bash

set -e

# Check if country parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <country> [instance_size]"
    echo ""
    echo "Available countries:"
    echo "  uk        - United Kingdom (London)"
    echo "  us-east   - United States (Virginia)"
    echo "  us-west   - United States (California)"
    echo "  de        - Germany (Frankfurt)"
    echo "  ie        - Ireland (Dublin)"
    echo "  sg        - Singapore"
    echo "  au        - Australia (Sydney)"
    echo "  jp        - Japan (Tokyo)"
    echo "  ca        - Canada (Toronto)"
    echo "  br        - Brazil (São Paulo)"
    echo ""
    echo "Instance sizes (optional, defaults to nano):"
    echo "  nano   - $3.50/month (512MB RAM, 1 vCPU)"
    echo "  micro  - $5.00/month (1GB RAM, 1 vCPU)"
    echo "  small  - $10.00/month (2GB RAM, 1 vCPU)"
    echo ""
    echo "Examples:"
    echo "  $0 uk"
    echo "  $0 us-east micro"
    echo "  $0 jp small"
    exit 1
fi

COUNTRY="$1"
INSTANCE_SIZE="${2:-nano}"

# Map instance size to bundle ID
case "$INSTANCE_SIZE" in
    nano)  BUNDLE_ID="nano_2_0" ;;
    micro) BUNDLE_ID="micro_2_0" ;;
    small) BUNDLE_ID="small_2_0" ;;
    *)     echo "❌ Invalid instance size. Use: nano, micro, or small"; exit 1 ;;
esac

# Map country to AWS region configuration
case "$COUNTRY" in
    uk)
        REGION="eu-west-2"
        AZ="eu-west-2a"
        COUNTRY_NAME="United Kingdom"
        ;;
    us-east)
        REGION="us-east-1"
        AZ="us-east-1a"
        COUNTRY_NAME="United States"
        COUNTRY="us"
        ;;
    us-west)
        REGION="us-west-1"
        AZ="us-west-1a"
        COUNTRY_NAME="United States"
        COUNTRY="us"
        ;;
    de)
        REGION="eu-central-1"
        AZ="eu-central-1a"
        COUNTRY_NAME="Germany"
        ;;
    ie)
        REGION="eu-west-1"
        AZ="eu-west-1a"
        COUNTRY_NAME="Ireland"
        ;;
    sg)
        REGION="ap-southeast-1"
        AZ="ap-southeast-1a"
        COUNTRY_NAME="Singapore"
        ;;
    au)
        REGION="ap-southeast-2"
        AZ="ap-southeast-2a"
        COUNTRY_NAME="Australia"
        ;;
    jp)
        REGION="ap-northeast-1"
        AZ="ap-northeast-1a"
        COUNTRY_NAME="Japan"
        ;;
    ca)
        REGION="ca-central-1"
        AZ="ca-central-1a"
        COUNTRY_NAME="Canada"
        ;;
    br)
        REGION="sa-east-1"
        AZ="sa-east-1a"
        COUNTRY_NAME="Brazil"
        ;;
    *)
        echo "❌ Unknown country: $COUNTRY"
        echo "Use: uk, us-east, us-west, de, ie, sg, au, jp, ca, br"
        exit 1
        ;;
esac

echo "🚀 Deploying VPN server in $COUNTRY_NAME ($REGION)"
echo "💾 Instance size: $INSTANCE_SIZE ($BUNDLE_ID)"

# Check prerequisites
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "❌ SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Please generate an SSH key pair first:"
    echo "ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\""
    exit 1
fi

if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured or credentials invalid"
    echo "Please configure AWS CLI first:"
    echo "aws configure"
    exit 1
fi

# Create terraform.tfvars file
cat > terraform.tfvars << EOF
country_config = {
  region            = "$REGION"
  availability_zone = "$AZ"
  country_code      = "$COUNTRY"
  country_name      = "$COUNTRY_NAME"
}

instance_bundle = "$BUNDLE_ID"

dns_config = {
  domain      = "your-domain.com"
  record_name = "vpn-$COUNTRY"
}
EOF

echo "📝 Created terraform.tfvars for $COUNTRY_NAME"

# Deploy infrastructure
echo "🔧 Initializing Terraform..."
terraform init

echo "📋 Planning infrastructure..."
terraform plan

echo "🏗️ Applying infrastructure..."
terraform apply -auto-approve

echo "⏳ Waiting for instance to be ready..."
sleep 90

# Get server details
SERVER_IP=$(terraform output -raw vpn_server_ip)
echo "🌐 VPN Server IP: $SERVER_IP"
echo "📍 Location: $COUNTRY_NAME ($REGION)"

# Wait for SSH access
echo "🔑 Waiting for SSH access..."
until ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$SERVER_IP 'exit' 2>/dev/null; do
    echo "Waiting for SSH..."
    sleep 10
done

# Wait for OpenVPN setup
echo "⏳ Waiting for OpenVPN setup to complete..."
ssh -o StrictHostKeyChecking=no ubuntu@$SERVER_IP 'sudo cloud-init status --wait'

# Check OpenVPN status
echo "🔍 Checking OpenVPN status..."
ssh -o StrictHostKeyChecking=no ubuntu@$SERVER_IP 'sudo systemctl status openvpn@server --no-pager'

# Download client configuration
echo "📥 Downloading client configuration..."
ssh -o StrictHostKeyChecking=no ubuntu@$SERVER_IP 'sudo cat /root/client-configs/files/client.ovpn' > "client-$COUNTRY.ovpn"

# Update client config with server IP
sed -i.bak "s/remote YOUR_VPN_SERVER_IP 1194/remote $SERVER_IP 1194/" "client-$COUNTRY.ovpn"

echo "✅ VPN setup complete!"
echo ""
echo "📱 Client configuration: client-$COUNTRY.ovpn"
echo "🌍 Server IP: $SERVER_IP"
echo "📍 Location: $COUNTRY_NAME"
echo "💰 Estimated cost: \$3.50-10/month (depending on size)"
echo ""
echo "🔗 To connect:"
echo "1. Install OpenVPN client"
echo "2. Import client-$COUNTRY.ovpn"
echo "3. Connect to VPN"
echo ""
echo "🔧 To manage server:"
echo "ssh ubuntu@$SERVER_IP"
echo ""
echo "🗑️ To destroy:"
echo "terraform destroy"