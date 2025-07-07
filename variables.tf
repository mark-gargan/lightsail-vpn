variable "country_config" {
  description = "VPN server configuration by country"
  type = object({
    region            = string
    availability_zone = string
    country_code      = string
    country_name      = string
  })
  
  validation {
    condition = contains([
      "us-east-1", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1", 
      "ap-southeast-1", "ap-southeast-2", "ap-northeast-1",
      "ca-central-1", "sa-east-1"
    ], var.country_config.region)
    error_message = "Region must be a valid AWS region."
  }
}

variable "dns_config" {
  description = "DNS configuration for the VPN"
  type = object({
    provider           = string
    domain             = string
    record_name        = string
    hosted_zone_id     = optional(string)
    dnsimple_token     = optional(string)
    dnsimple_account_id = optional(string)
  })
  default = {
    provider           = "none"
    domain             = "your-domain.com"
    record_name        = "vpn"
    hosted_zone_id     = ""
    dnsimple_token     = ""
    dnsimple_account_id = ""
  }
  
  validation {
    condition = contains(["none", "route53", "dnsimple"], var.dns_config.provider)
    error_message = "DNS provider must be 'none', 'route53', or 'dnsimple'."
  }
}

variable "instance_bundle" {
  description = "Lightsail instance bundle size"
  type        = string
  default     = "nano_2_0"
  
  validation {
    condition = contains([
      "nano_2_0", "micro_2_0", "small_2_0", "medium_2_0", "large_2_0"
    ], var.instance_bundle)
    error_message = "Bundle must be a valid Lightsail bundle."
  }
}