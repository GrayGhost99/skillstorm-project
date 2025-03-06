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

  #Service Endpoint
  service_endpoints = ["Microsoft.Storage"]
}
# data subnet
resource "azurerm_subnet" "data_snt" {
  name                 = "data-snt"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]

  # Service Endpoint
  service_endpoints = ["Microsoft.Sql"]
}
# Bastion subnet
resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Bastion for testing
resource "azurerm_public_ip" "bastion_ip" {
  name                = "bastion_ip"
  location            = var.vnet_loc
  resource_group_name = var.rg
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_bastion_host" "bastion_jumpbox" {
  name                = "bastion-jumpbox"
  location            = var.vnet_loc
  resource_group_name = var.rg

  ip_configuration {
    name                 = "bastion-ip-configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}

# Network Security Groups
# web-snt NSG
resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = var.vnet_loc
  resource_group_name = var.rg

  # Allow inbound HTTP traffic on port 80
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

  # Allow outbound SQL to data_snt port 1433
  security_rule {
    name                       = "Allow_SQL_Outbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_subnet.data_snt.address_prefixes[0]
  }

  # Allow inbound traffic from the Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancerInBound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "web_snt_nsg_association" {
  subnet_id                 = azurerm_subnet.web_snt.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

# data-snt NSG
# Network Security Group for data_snt subnet - Allow only SQL traffic from VMSS (web_snt)
resource "azurerm_network_security_group" "data_nsg" {
  name                = "data-nsg"
  location            = var.vnet_loc
  resource_group_name = var.rg

  # Allow inbound SQL traffic (port 1433) from the web_snt subnet (VMSS only)
  security_rule {
    name                       = "Allow_SQL_From_VMSS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = azurerm_subnet.web_snt.address_prefixes[0]
    destination_address_prefix = "*"
  }

  # Allow outbound SQL traffic (port 1433) to the VMSS in web_snt subnet
  security_rule {
    name                       = "Allow_SQL_To_VMSS"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_subnet.web_snt.address_prefixes[0]
  }

  # DENY ALL In
  security_rule {
    name                       = "Deny_All_IN_data_snt"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # DENY ALL Out
  security_rule {
    name                       = "Deny_All_OUT_data_snt"
    priority                   = 500
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "data_snt_nsg_association" {
  subnet_id                 = azurerm_subnet.data_snt.id
  network_security_group_id = azurerm_network_security_group.data_nsg.id
}

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
resource "azurerm_orchestrated_virtual_machine_scale_set" "web_ss" {
  name                = "web-vmss"
  resource_group_name = var.rg
  location            = var.vnet_loc
  sku_name            = "Standard_F2"
  instances           = 2
  #admin_username                  = var.vmss_admin_username
  #admin_password                  = var.vmss_admin_password
  #disable_password_authentication = false
  #health_probe_id                 = azurerm_lb_probe.http_probe.id
  platform_fault_domain_count = 2

  # OS Upgrades
  #upgrade_mode = "Automatic"

  # automatic_os_upgrade_policy {
  #   enable_automatic_os_upgrade = true
  #   disable_automatic_rollback  = false
  # }

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


  # Startup script to install Nginx and create static index.html with hostname
  custom_data = base64encode(<<-EOT
    #!/bin/bash
    sudo apt-get update -y
    apt-get install -y nginx
    sudo snap install azcli
    sudo apt-get install -y curl apt-transport-https
    curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
    curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
    sudo apt-get update -y
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
    source ~/.bashrc


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

#VMSS Auto-scale
resource "azurerm_monitor_autoscale_setting" "vmss_autoscaling" {
  name                = "AutoscaleSetting"
  resource_group_name = var.rg
  location            = var.vnet_loc
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_ss.id

  profile {
    name = "CPU_Load_Profile"

    capacity {
      default = 2
      minimum = 2
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_ss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_ss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
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


# MSSQL Server and DB
# Azure SQL Server
resource "azurerm_mssql_server" "sql_server" {
  name                         = "data-snt-sql-server"
  resource_group_name          = var.rg
  location                     = var.vnet_loc
  version                      = "12.0"
  administrator_login          = var.vmss_admin_username
  administrator_login_password = var.vmss_admin_password

  minimum_tls_version = "1.2"
}
# Azure SQL Database
resource "azurerm_mssql_database" "data_snt_db" {
  name      = "datadb"
  server_id = azurerm_mssql_server.sql_server.id
  sku_name  = "Basic"
}
# Allow web_snt subnet to access SQL Server
resource "azurerm_mssql_firewall_rule" "allow_web_tier" {
  name             = "AllowWebTierSubnet"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = cidrhost(azurerm_subnet.web_snt.address_prefixes[0], 1)
  end_ip_address   = cidrhost(azurerm_subnet.web_snt.address_prefixes[0], 254)
}
