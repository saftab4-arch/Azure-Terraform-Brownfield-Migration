resource "azurerm_resource_group" "res-0" {
  location = "eastus"
  name     = "1-ab3ea420-playground-sandbox"
}
resource "azurerm_linux_virtual_machine" "res-1" {
  admin_username        = "azureuser"
  location              = "westus2"
  name                  = "brownfield-app-vm"
  network_interface_ids = [azurerm_network_interface.res-4.id]
  resource_group_name   = azurerm_resource_group.res-0.name
  secure_boot_enabled   = true
  size                  = "Standard_D2s_v3"
  vtpm_enabled          = true
  additional_capabilities {
  }
  boot_diagnostics {
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "res-2" {
  admin_username        = "azureuser"
  location              = "westus2"
  name                  = "brownfield-db-vm"
  network_interface_ids = [azurerm_network_interface.res-5.id]
  resource_group_name   = azurerm_resource_group.res-0.name
  secure_boot_enabled   = true
  size                  = "Standard_D2s_v3"
  vtpm_enabled          = true
  additional_capabilities {
  }
  boot_diagnostics {
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_linux_virtual_machine" "res-3" {
  admin_username        = "azureuser"
  location              = "westus2"
  name                  = "brownfield-web-vm"
  network_interface_ids = [azurerm_network_interface.res-6.id]
  resource_group_name   = azurerm_resource_group.res-0.name
  secure_boot_enabled   = true
  size                  = "Standard_D2s_v3"
  vtpm_enabled          = true
  additional_capabilities {
  }
  boot_diagnostics {
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "canonical"
    sku       = "server"
    version   = "latest"
  }
}
resource "azurerm_network_interface" "res-4" {
  location            = "westus2"
  name                = "brownfield-app-vm704"
  resource_group_name = azurerm_resource_group.res-0.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Network/virtualNetworks/brownfield-vnet/subnets/app-subnet"
  }
  depends_on = [
    # One of azurerm_subnet.res-18,azurerm_subnet_network_security_group_association.res-19,azurerm_subnet_route_table_association.res-20 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_interface" "res-5" {
  location            = "westus2"
  name                = "brownfield-db-vm330"
  resource_group_name = azurerm_resource_group.res-0.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Network/virtualNetworks/brownfield-vnet/subnets/db-subnet"
  }
  depends_on = [
    # One of azurerm_subnet.res-21,azurerm_subnet_network_security_group_association.res-22 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_interface" "res-6" {
  location            = "westus2"
  name                = "brownfield-web-vm596"
  resource_group_name = azurerm_resource_group.res-0.name
  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.res-13.id
    subnet_id                     = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Network/virtualNetworks/brownfield-vnet/subnets/web-subnet"
  }
  depends_on = [
    # One of azurerm_subnet.res-23,azurerm_subnet_network_security_group_association.res-24 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_network_security_group" "res-7" {
  location            = "westus2"
  name                = "app-nsg"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_network_security_rule" "res-8" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "8080"
  direction                   = "Inbound"
  name                        = "allow-web-to-app"
  network_security_group_name = "app-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-0.name
  source_address_prefix       = "10.20.1.0/24"
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-7,
  ]
}
resource "azurerm_network_security_group" "res-9" {
  location            = "westus2"
  name                = "db-nsg"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_network_security_rule" "res-10" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "5432"
  direction                   = "Inbound"
  name                        = "allow-app-to-db"
  network_security_group_name = "db-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-0.name
  source_address_prefix       = "10.20.2.0/24"
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-9,
  ]
}
resource "azurerm_network_security_group" "res-11" {
  location            = "westus2"
  name                = "web-nsg"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_network_security_rule" "res-12" {
  access                      = "Allow"
  destination_address_prefix  = "*"
  destination_port_range      = "80"
  direction                   = "Inbound"
  name                        = "web-nsg-inbound"
  network_security_group_name = "web-nsg"
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.res-0.name
  source_address_prefix       = "*"
  source_port_range           = "*"
  depends_on = [
    azurerm_network_security_group.res-11,
  ]
}
resource "azurerm_public_ip" "res-13" {
  allocation_method   = "Static"
  location            = "westus2"
  name                = "brownfield-web-vm-ip"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_route_table" "res-14" {
  location            = "westus2"
  name                = "brownfield-app-rt"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_route" "res-15" {
  address_prefix      = "10.20.1.0/24"
  name                = "Route-to-web"
  next_hop_type       = "VnetLocal"
  resource_group_name = azurerm_resource_group.res-0.name
  route_table_name    = "brownfield-app-rt"
  depends_on = [
    azurerm_route_table.res-14,
  ]
}
resource "azurerm_route" "res-16" {
  address_prefix      = "10.20.3.0/24"
  name                = "route-to-db"
  next_hop_type       = "VnetLocal"
  resource_group_name = azurerm_resource_group.res-0.name
  route_table_name    = "brownfield-app-rt"
  depends_on = [
    azurerm_route_table.res-14,
  ]
}
resource "azurerm_virtual_network" "res-17" {
  address_space       = ["10.20.0.0/16"]
  location            = "westus2"
  name                = "brownfield-vnet"
  resource_group_name = azurerm_resource_group.res-0.name
}
resource "azurerm_subnet" "res-18" {
  address_prefixes                = ["10.20.2.0/24"]
  default_outbound_access_enabled = false
  name                            = "app-subnet"
  resource_group_name             = azurerm_resource_group.res-0.name
  virtual_network_name            = "brownfield-vnet"
  depends_on = [
    azurerm_virtual_network.res-17,
  ]
}
resource "azurerm_subnet_network_security_group_association" "res-19" {
  network_security_group_id = azurerm_network_security_group.res-7.id
  subnet_id                 = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Network/virtualNetworks/brownfield-vnet/subnets/app-subnet"
  depends_on = [
    azurerm_subnet.res-18,
    # One of azurerm_subnet.res-18,azurerm_subnet_route_table_association.res-20 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_subnet_route_table_association" "res-20" {
  route_table_id = azurerm_route_table.res-14.id
  subnet_id      = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Network/virtualNetworks/brownfield-vnet/subnets/app-subnet"
  depends_on = [
    azurerm_subnet.res-18,
    # One of azurerm_subnet.res-18,azurerm_subnet_network_security_group_association.res-19 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_subnet" "res-21" {
  address_prefixes                = ["10.20.3.0/24"]
  default_outbound_access_enabled = false
  name                            = "db-subnet"
  resource_group_name             = azurerm_resource_group.res-0.name
  virtual_network_name            = "brownfield-vnet"
  depends_on = [
    azurerm_virtual_network.res-17,
  ]
}
resource "azurerm_subnet_network_security_group_association" "res-22" {
  network_security_group_id = azurerm_network_security_group.res-9.id
  subnet_id                 = azurerm_subnet.res-21.id
}
resource "azurerm_subnet" "res-23" {
  address_prefixes                = ["10.20.1.0/24"]
  default_outbound_access_enabled = false
  name                            = "web-subnet"
  resource_group_name             = azurerm_resource_group.res-0.name
  virtual_network_name            = "brownfield-vnet"
  depends_on = [
    azurerm_virtual_network.res-17,
  ]
}
resource "azurerm_subnet_network_security_group_association" "res-24" {
  network_security_group_id = azurerm_network_security_group.res-11.id
  subnet_id                 = azurerm_subnet.res-23.id
}
resource "azurerm_storage_account" "res-25" {
  account_replication_type        = "LRS"
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = false
  location                        = "westus2"
  name                            = "tfstatebrownfield2026"
  resource_group_name             = azurerm_resource_group.res-0.name
}
resource "azurerm_storage_container" "res-27" {
  name               = "tfstate"
  storage_account_id = "/subscriptions/2213e8b1-dbc7-4d54-8aff-b5e315df5e5b/resourceGroups/1-ab3ea420-playground-sandbox/providers/Microsoft.Storage/storageAccounts/tfstatebrownfield2026"
  depends_on = [
    # One of azurerm_storage_account.res-25,azurerm_storage_account_queue_properties.res-29 (can't auto-resolve as their ids are identical)
  ]
}
resource "azurerm_storage_account_queue_properties" "res-29" {
  storage_account_id = azurerm_storage_account.res-25.id
  hour_metrics {
    version = "1.0"
  }
  logging {
    delete  = false
    read    = false
    version = "1.0"
    write   = false
  }
  minute_metrics {
    version = "1.0"
  }
}
