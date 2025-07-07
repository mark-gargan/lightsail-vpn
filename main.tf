terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.country_config.region
}

# Create Lightsail instance
resource "aws_lightsail_instance" "vpn_server" {
  name              = "vpn-${var.country_config.country_code}-lightsail-server"
  availability_zone = var.country_config.availability_zone
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = var.instance_bundle
  key_pair_name     = aws_lightsail_key_pair.vpn_key.name
  user_data         = file("${path.module}/user-data.sh")

  tags = {
    Name        = "VPN ${var.country_config.country_name} Lightsail Server"
    Country     = var.country_config.country_name
    CountryCode = var.country_config.country_code
  }
}

# Create key pair for SSH access
resource "aws_lightsail_key_pair" "vpn_key" {
  name       = "vpn-${var.country_config.country_code}-lightsail-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Create static IP
resource "aws_lightsail_static_ip" "vpn_ip" {
  name = "vpn-${var.country_config.country_code}-lightsail-static-ip"
}

# Attach static IP to instance
resource "aws_lightsail_static_ip_attachment" "vpn_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.vpn_ip.name
  instance_name  = aws_lightsail_instance.vpn_server.name
}

# Open firewall ports
resource "aws_lightsail_instance_public_ports" "vpn_ports" {
  instance_name = aws_lightsail_instance.vpn_server.name

  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }

  port_info {
    protocol  = "udp"
    from_port = 1194
    to_port   = 1194
  }

  port_info {
    protocol  = "tcp"
    from_port = 443
    to_port   = 443
  }
}

# Output the static IP
output "vpn_server_ip" {
  value = aws_lightsail_static_ip.vpn_ip.ip_address
}

output "vpn_server_username" {
  value = "ubuntu"
}