provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "myudacityservice" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_virtual_network" "myudacityvnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.myudacityservice.name

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_subnet" "myudacitysnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.myudacityservice.name
  virtual_network_name = azurerm_virtual_network.myudacityvnet.name
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "myudacitypip" {
  name                         = "${var.prefix}-public-ip"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.myudacityservice.name
  allocation_method            = "Static"
  domain_name_label            = azurerm_resource_group.myudacityservice.name

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_network_security_group" "myudacityweb" {
  name                = "${var.prefix}-web-nsg"
  location            = azurerm_resource_group.myudacityservice.location
  resource_group_name = azurerm_resource_group.myudacityservice.name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "tls"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_port_range     = "443"
    destination_address_prefix = azurerm_subnet.myudacitysnet.address_prefix
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_network_security_group" "myudacityssh" {
  name                = "${var.prefix}-ssh-nsg"
  location            = azurerm_resource_group.myudacityservice.location
  resource_group_name = azurerm_resource_group.myudacityservice.name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "ssh"
    priority                   = 200
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_port_range     = "22"
    destination_address_prefix = azurerm_subnet.myudacitysnet.address_prefix
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_network_interface" "myudacitynic" {
  count               = var.no_of_instances
  name                = "${var.prefix}-nic${count.index}"
  resource_group_name = azurerm_resource_group.myudacityservice.name
  location            = azurerm_resource_group.myudacityservice.location

  ip_configuration {
    name                          = "devConfiguration"
    subnet_id                     = azurerm_subnet.myudacitysnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_lb" "myudacitylb" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.myudacityservice.location
  resource_group_name = azurerm_resource_group.myudacityservice.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.myudacitypip.id
  }

  tags = {
    Environment = "Development"
  }
}

resource "azurerm_lb_backend_address_pool" "myudacitybepool" {
  resource_group_name = azurerm_resource_group.myudacityservice.name
  loadbalancer_id     = azurerm_lb.myudacitylb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "myudacitynatrule" {
  resource_group_name            = azurerm_resource_group.myudacityservice.name
  loadbalancer_id                = azurerm_lb.myudacitylb.id
  name                           = "HTTPSAccess"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.myudacitylb.frontend_ip_configuration[0].name
}

resource "azurerm_network_interface_backend_address_pool_association" "myudacitynicbepool" {
  count                   = var.no_of_instances
  backend_address_pool_id = azurerm_lb_backend_address_pool.myudacitybepool.id
  ip_configuration_name   = "devConfiguration"
  network_interface_id    = element(azurerm_network_interface.myudacitynic.*.id, count.index)
}

resource "azurerm_availability_set" "myudacityavset" {
  name                         = "${var.prefix}-avset"
  location                     = azurerm_resource_group.myudacityservice.location
  resource_group_name          = azurerm_resource_group.myudacityservice.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true

  tags = {
    Environment = "Development"
  }
}

data "azurerm_image" "packerimage" {
  name                = "myUdacityC01PackerImage"
  resource_group_name = "myudacitypkrdrc01-rg"
}

resource "azurerm_linux_virtual_machine" "myudacitylinuxvm" {
  count                           = var.no_of_instances
  name                            = "${var.prefix}-vm${count.index}"
  resource_group_name             = azurerm_resource_group.myudacityservice.name
  location                        = azurerm_resource_group.myudacityservice.location
  availability_set_id             = azurerm_availability_set.myudacityavset.id
  size                            = "Standard_D2s_V3"
  network_interface_ids = [
    azurerm_network_interface.myudacitynic[count.index].id,
  ]
  
  computer_name  = "${var.prefix}-webserver"
  admin_username = "adminuser"
  admin_password = var.admin_password

  disable_password_authentication = false

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  source_image_id = data.azurerm_image.packerimage.id

  tags = {
    Environment = "Development"
  }
}
