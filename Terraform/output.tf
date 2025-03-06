# output.tf

# Load balancer IP
output "load_balancer_ip" {
  value       = azurerm_public_ip.web_pub_ip.ip_address
  description = "The public IP address of the load balancer."
}

