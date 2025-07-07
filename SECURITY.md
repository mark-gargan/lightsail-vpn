# Security Policy

## Supported Versions

This project is actively maintained. Please use the latest version from the main branch.

## Reporting a Vulnerability

If you discover a security vulnerability, please send an email to the maintainers. Please do not create a public GitHub issue for security vulnerabilities.

## Security Considerations

### What This Project Does
- Creates OpenVPN servers on AWS Lightsail for geo-location purposes
- Generates certificates and keys for VPN authentication
- Provides scripts for DNS management

### Security Best Practices
- All private keys and certificates are generated fresh for each deployment
- No hardcoded credentials or keys in the repository
- Uses AWS IAM for authentication (no access keys in code)
- Follows OpenVPN security best practices (AES-256-GCM, SHA256)

### What Users Should Do
- Keep your AWS credentials secure
- Regularly update your VPN server with security patches
- Monitor VPN access logs for suspicious activity
- Rotate certificates periodically
- Use strong DNS provider credentials

### What This Project Does NOT Do
- Store or transmit your credentials
- Keep logs of your VPN traffic
- Share your certificates or keys
- Access your AWS account beyond what you explicitly deploy

## Dependencies
This project uses standard tools:
- Terraform (infrastructure)
- AWS CLI (cloud management)
- OpenVPN (VPN software)
- Standard Linux utilities

All dependencies should be obtained from official sources.