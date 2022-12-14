variable "prefix" {
  default = "sridhar-docker"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = "ranjith"
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "ranjith"
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.prefix}_public_ip"
  resource_group_name = "ranjith"
  location            = "eastus"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = "eastus"
  resource_group_name = "ranjith"

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = "eastus"
  resource_group_name = "ranjith"

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-java-vm"
  location              = "eastus"
  resource_group_name   = "ranjith"
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_D2S_V3"
  delete_os_disk_on_termination = "true"

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true
  
  plan {
    name      = "ubuntu1804lts-python-docker-zerto"
    publisher = "zerto"
    product   = "azure-vms-by-zerto"
  }

  storage_image_reference {
    publisher = "zerto"
    offer     = "azure-vms-by-zerto"
    sku       = "ubuntu1804lts-python-docker-zerto"
    version   = "1.0.0"
  }
  storage_os_disk {
    name              = "${var.prefix}-osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.prefix}-machine"
    admin_username = "azuser"
    admin_password = "Arti@12345678"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_machine_extension" "vm_extension_install_docker_images" {
  name                 = "${var.prefix}-vm_extension_install_docker_images"
  virtual_machine_id   = azurerm_virtual_machine.main.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(templatefile("custom_script.sh", {
          vmname="${azurerm_virtual_machine.main.name}"
        }))}"
    }
SETTINGS
}