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
    domain      = string
    record_name = string
  })
  default = {
    domain      = "your-domain.com"
    record_name = "vpn"
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