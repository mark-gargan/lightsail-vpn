# Multi-Country VPN Server Setup

This project creates an OpenVPN server on AWS Lightsail in various countries for geo-location purposes (streaming, gaming, etc.).

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed
3. SSH key pair generated (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)

## Quick Start

1. **Deploy a VPN server in your desired country:**
   ```bash
   ./deploy.sh <country> [instance_size]
   ```

   **Available countries:**
   - `uk` - United Kingdom (London)
   - `us-east` - United States (Virginia)
   - `us-west` - United States (California) 
   - `de` - Germany (Frankfurt)
   - `ie` - Ireland (Dublin)
   - `sg` - Singapore
   - `au` - Australia (Sydney)
   - `jp` - Japan (Tokyo)
   - `ca` - Canada (Toronto)
   - `br` - Brazil (São Paulo)

   **Examples:**
   ```bash
   ./deploy.sh uk           # UK server, nano instance
   ./deploy.sh us-east micro  # US East server, micro instance
   ./deploy.sh jp small     # Japan server, small instance
   ```

2. **Transfer the client config to your device:**
   - The script generates `client-<country>.ovpn`
   - Transfer this file to your device

3. **Install OpenVPN client:**
   - Download OpenVPN Connect
   - Import the `.ovpn` file
   - Connect to the VPN

## DNS Setup (Optional)

**Note:** DNS setup is not strictly necessary since Lightsail provides a static IP address that won't change. However, using a domain name can be more convenient and memorable.

To use a custom domain instead of IP address:

### Option 1: DNSimple
```bash
./dns-setup-dnsimple.sh YOUR_DNSIMPLE_TOKEN YOUR_DNSIMPLE_ACCOUNT_ID
```

### Option 2: AWS Route53
```bash
./dns-setup-route53.sh HOSTED_ZONE_ID DOMAIN_NAME [RECORD_NAME]
```

**Examples:**
```bash
# DNSimple setup
./dns-setup-dnsimple.sh YOUR_DNSIMPLE_TOKEN YOUR_ACCOUNT_ID

# Route53 setup  
./dns-setup-route53.sh Z1234567890ABC example.com
./dns-setup-route53.sh Z1234567890ABC example.com vpn-uk
```

This will create DNS records like:
- `vpn.example.com` → your server IP
- `vpn-uk.example.com` → your UK server IP

### Option 3: AWS Route53 (Advanced)

If you want to use Route53 with your own domain:

1. **Set up a hosted zone in Route53:**
   ```bash
   # Create hosted zone (one-time setup)
   aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)
   ```

2. **Configure DNS updates:**
   ```bash
   ./dns-setup-route53.sh YOUR_HOSTED_ZONE_ID example.com
   ```

3. **Update your domain's nameservers** to point to the Route53 nameservers from step 1.

**Route53 Requirements:**
- Your own domain name
- AWS Route53 hosted zone (~$0.50/month)
- DNS nameserver configuration at your domain registrar

## Manual Setup

If you prefer manual setup:

```bash
# Initialize Terraform
terraform init

# Plan and apply
terraform plan
terraform apply

# Get server IP
SERVER_IP=$(terraform output -raw vpn_server_ip)

# Wait for setup to complete
ssh ubuntu@$SERVER_IP 'sudo cloud-init status --wait'

# Download client config
ssh ubuntu@$SERVER_IP 'sudo cat /root/client-configs/files/client.ovpn' > client.ovpn
```

## Configuration Details

- **Platform:** AWS Lightsail
- **Regions:** Multiple AWS regions worldwide
- **Instance Types:** 
  - nano (1 vCPU, 0.5GB RAM) - $3.50/month
  - micro (1 vCPU, 1GB RAM) - $5.00/month  
  - small (1 vCPU, 2GB RAM) - $10.00/month
- **VPN Protocol:** UDP port 1194
- **Encryption:** AES-256-GCM
- **Authentication:** SHA256

## Costs

- Lightsail instances: $3.50-10/month (depending on size)
- Static IP: Included (no extra charge)
- Data transfer: 1TB included per month
- Multiple countries: Each server billed separately

## Troubleshooting

### Connection Issues
1. Verify instance is running in Lightsail console
2. Check OpenVPN service status:
   ```bash
   ssh ubuntu@$SERVER_IP 'sudo systemctl status openvpn@server'
   ```
3. Ensure firewall allows UDP 1194

### Performance Issues
- Upgrade to micro ($5/month) for better performance
- Monitor data transfer usage

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## DNS Providers

### DNS Provider Comparison

| Provider | Pros | Cons |  Setup |
|----------|------|------|------|
| **None (IP only)** | Free, simple, static IP included | Hard to remember IP address |  Default |
| **DNSimple** | Simple API, good docs | Third-party service |  `./dns-setup-dnsimple.sh` |
| **Route53** | AWS native, fast propagation | Requires domain + setup | `./dns-setup-route53.sh` |
| **Manual** | Any DNS provider | Manual management |  Create A record manually |

**Recommendation:** Start without DNS (use the IP directly). Add DNS later if you want a memorable domain name.

## Security Notes

- Regularly update the server with security patches
- Monitor access logs for suspicious activity
- Consider rotating certificates periodically
- Use strong passwords for any additional services
- Route53 requires AWS IAM permissions: `route53:ChangeResourceRecordSets`, `route53:GetHostedZone`