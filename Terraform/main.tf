# main tf

# VNet and subnets
#VNet
resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  location            = var.vnet_loc
  resource_group_name = var.rg
  address_space       = ["10.0.0.0/16"]
}
# web subnet
resource "azurerm_subnet" "web_snt" {
  name                 = "web-snt"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}
# data subnet
resource "azurerm_subnet" "data_snt" {
  name                 = "data-snt"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Bastion for testing                                          # unless can automate file transfer in startup script finish this up / needed for testing
# resource "azurerm_bastion_host" "my_bastion" {                # maybe add sas token creation for container and import it for script?
#   name                = "VNet1-bastion"
#   location            = var.vnet_loc
#   resource_group_name = var.rg
#   virtual_network_id  = azurerm_virtual_network.vnet1.id
# }

# Network Security Groups
# web-snt NSG
resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = var.vnet_loc
  resource_group_name = var.rg

  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "web_snt_nsg_association" {
  subnet_id                 = azurerm_subnet.web_snt.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# data-snt NSG                                                                                                             STILL NEEDED

# Load Balancer and related items
# PubIP for the LB
resource "azurerm_public_ip" "web_pub_ip" {
  name                = "PublicIPForLB"
  location            = var.vnet_loc
  resource_group_name = var.rg
  allocation_method   = "Static"
}
# LB
resource "azurerm_lb" "web_lb" {
  name                = "Web-LB"
  location            = var.vnet_loc
  resource_group_name = var.rg

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.web_pub_ip.id
  }
}
# Backend Address Pool for the LB
resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name            = "WebBackendPool"
  loadbalancer_id = azurerm_lb.web_lb.id

}
# LB HTTP rule
resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.web_lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id

  depends_on = [
    azurerm_public_ip.web_pub_ip
  ]
}


# Virtual Machine Scale Set
# VMSS configuration
resource "azurerm_linux_virtual_machine_scale_set" "web_ss" {
  name                            = "web-vmss"
  resource_group_name             = var.rg
  location                        = var.vnet_loc
  sku                             = "Standard_F2"
  instances                       = 2
  admin_username                  = var.vmss_admin_username
  admin_password                  = var.vmss_admin_password
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss_nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.web_snt.id
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.web_backend_pool.id
      ]
    }
  }
  # see bastion notes for details
  # Startup script to install Nginx and create static index.html with hostname                    Possibly add the copy command back to move files in storage
  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    sudo snap install azcli

    # Get instance hostname
    hostname=$(hostname)

    # Use hostname to create html for each vm
    # Can refresh screen to show different hosts for Load Balancer function
    echo "<html><head><title>Welcome</title></head><body><h1>Hello, World - This is $${hostname}</h1></body></html>" > /var/www/html/index.html

    # Start nginx
    systemctl enable nginx
    systemctl start nginx
  EOT
  )

  depends_on = [
    azurerm_lb.web_lb
  ]
}

# VMSS Health Probes
resource "azurerm_lb_probe" "http_probe" {
  name                = "httpProbe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# SQL DB                                                                                                 STILL NEEDED

# Storage account
resource "azurerm_storage_account" "storage" {
  name                     = "vmssdatastorage"
  resource_group_name      = var.rg
  location                 = var.vnet_loc
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action = "Deny"
    # Allow access from the VMSS VNet
    virtual_network_subnet_ids = [azurerm_subnet.web_snt.id]
  }
}

# Storage Container
resource "azurerm_storage_container" "vmss_container" {
  name                  = "vmss-container"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"

  depends_on = [azurerm_storage_account.storage]
}
