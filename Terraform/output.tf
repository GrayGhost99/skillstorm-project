# output.tf

# vnet output
output "vnet_details" {
  value = {
    id            = azurerm_virtual_network.vnet1.id
    name          = azurerm_virtual_network.vnet1.name
    location      = azurerm_virtual_network.vnet1.location
    address_space = azurerm_virtual_network.vnet1.address_space
  }
}

# subnet output
output "subnet_details" {
  value = {
    subnet1_name          = azurerm_subnet.web_snt.name,
    subnet1_address_space = azurerm_subnet.web_snt.address_prefixes,
    subnet1_id            = azurerm_subnet.web_snt.id,
    subnet2_name          = azurerm_subnet.data_snt.name,
    subnet2_address_space = azurerm_subnet.data_snt.address_prefixes,
    subnet2_id            = azurerm_subnet.data_snt.id
  }
}

# Load balancer IP
output "load_balancer_ip" {
  value       = azurerm_public_ip.web_pub_ip.ip_address
  description = "The public IP address of the load balancer."
}

