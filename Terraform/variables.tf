# variables.tf

# Creds
variable "sub" {
  description = "Subscription Info"
  type        = string
  default     = ""
}

# Resource Group vars
variable "rg" {
  description = "Resource Group Name"
  type        = string
  default     = ""
}


#VNET Vars
variable "vnet1_name" {
  description = "Name of VNet1"
  type        = string
  default     = ""
}
variable "vnet_loc" {
  description = "VNet location"
  type        = string
  default     = ""
}
