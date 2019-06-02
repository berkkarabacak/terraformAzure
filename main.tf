resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}
resource "azurerm_resource_group" "test" {
  name     = "${var.prefix}_estrg"
  location = "West US 2"
}

resource "azurerm_virtual_network" "test" {
  name                = "${var.prefix}_vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
}

resource "azurerm_subnet" "test" {
  name                 = "${var.prefix}_sub"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "ipforbackendvm" {
  name                = "ipforbackendvm"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}"
}


resource "azurerm_network_security_group" "test" {
  name                = "acceptanceTestSecurityGroup1"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  security_rule {
    name                       = "test0"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "test1"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "test" {
  count                     = "${var.redundancy_count}"
  name                      = "${var.prefix}_ni${count.index}"
  location                  = "${azurerm_resource_group.test.location}"
  resource_group_name       = "${azurerm_resource_group.test.name}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"

  ip_configuration {
    name                          = "testConfiguration${count.index}"
    subnet_id                     = "${azurerm_subnet.test.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "10.0.2.${count.index + 10}"
    public_ip_address_id          = "${ count.index > 1 ? azurerm_public_ip.ipforbackendvm.id : "" }"
  }
}
resource "azurerm_virtual_machine" "test" {
  count                 = "${var.redundancy_count}"
  name                  = "${var.prefix}vm${count.index}"
  location              = "${azurerm_resource_group.test.location}"
  resource_group_name   = "${azurerm_resource_group.test.name}"
  network_interface_ids = ["${element(azurerm_network_interface.test.*.id, count.index)}"]
  vm_size               = "Standard_DS1_v2"

  # Purpose of this line is to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Purpose of this line is to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
    custom_data    = "${base64encode(data.template_file.init.rendered)}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "staging"
  }
}

data "template_file" "init" {
  template = "${file("init.tpl")}"
  vars = {
    QuoteServicePrivateIP     = "${element(azurerm_network_interface.test.*.private_ip_address, 0)}"
    NewsfeedServicePrivateIP  = "${element(azurerm_network_interface.test.*.private_ip_address, 1)}"
    FrontEndServicePrivateIP  = "${element(azurerm_network_interface.test.*.private_ip_address, 2)}"
    FrontEndServicePublicIP   = "${azurerm_public_ip.ipforbackendvm.ip_address}"
    QuoteServicePort          = "${var.QuoteServicePort}"
    NewsfeedServicePort       = "${var.NewsfeedServicePort}"
    FrontEndServicePort       = "${var.FrontEndServicePort}"
    Username                  = "${var.admin_username}"
  }
}
output "public_address_frontend" {
     value = "${azurerm_public_ip.ipforbackendvm.fqdn}:${var.FrontEndServicePort}"
 }
