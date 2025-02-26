# main tf

# module "vnet" {
#   source  = "Azure/vnet/azurerm"
#   version = "5.0.1"
#   # insert the 2 required variables here
#   resource_group_name = var.rg
#   vnet_location       = var.vnet_loc
# }

resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1_name
  location            = var.vnet_loc
  resource_group_name = var.rg
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "web_snt" {
  name                 = "web-snt"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "data_snt" {
  name                 = "data-snt"
  resource_group_name  = var.rg
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]
}

