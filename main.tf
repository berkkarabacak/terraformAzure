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
  count               = "${var.redundancy_count}"
  name                = "ipforbackendvm_${count.index}"
  location            = "${azurerm_resource_group.test.location}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  allocation_method   = "Static"
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
    private_ip_address            = "10.0.2.${count.index + 20}"
    public_ip_address_id          = "${element(azurerm_public_ip.ipforbackendvm.*.id, count.index)}"
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
  # vars = {
  #   cluster_size                = "${var.cluster_size}"
  #   consul_version              = "${var.consul_version}"
  #   consul_datacenter           = "${var.consul_datacenter}"
  #   consul_join_wan             = "${join(" ", var.consul_join_wan)}"
  #   auto_join_subscription_id   = "${var.auto_join_subscription_id}"
  #   auto_join_tenant_id         = "${var.auto_join_tenant_id}"
  #   auto_join_client_id         = "${var.auto_join_client_id}"
  #   auto_join_secret_access_key = "${var.auto_join_client_secret}"
  # }
}
# resource "null_resource" "assets" {
#   depends_on = ["azurerm_virtual_machine.test"]
#   # Changes to any instance of the vms requires re-provisioning
#   triggers = {
#     vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id, 0)}"
#   }

#   connection {
#     type     = "ssh"
#     host     = "${element(azurerm_public_ip.ipforbackendvm.*.ip_address, 0)}"
#     user     = "${var.admin_username}"
#     password = "${var.admin_password}"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo systemctl enable Assets",
#       "sudo systemctl start Assets"
#     ]
#   }
# }

# resource "null_resource" "quote" {
#   depends_on = ["azurerm_virtual_machine.test"]

#   triggers = {
#     vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id, 1)}"
#   }

#   connection {
#     type     = "ssh"
#     host     = "${element(azurerm_public_ip.ipforbackendvm.*.ip_address, 1)}"
#     user     = "${var.admin_username}"
#     password = "${var.admin_password}"
#   }

#   provisioner "file" {
#     source      = "scriptquote.sh"
#     destination = "/tmp/scriptquote.sh"
#   }

#   provisioner "remote-exec" {
#       inline = [
#       "chmod +x /tmp/scriptquote.sh",
#       "source /tmp/scriptquote.sh",
#       "sudo systemctl enable Quote",
#       "sudo systemctl start Quote"
#     ]
#   }
# }

# resource "null_resource" "Newsfeed" {
#   depends_on = ["azurerm_virtual_machine.test"]

#   triggers = {
#     vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id, 2)}"
#   }
#   connection {
#     type     = "ssh"
#     host     = "${element(azurerm_public_ip.ipforbackendvm.*.ip_address, 2)}"
#     user     = "${var.admin_username}"
#     password = "${var.admin_password}"
#   }
 
#   provisioner "file" {
#     source      = "scriptnewsfeed.sh"
#     destination = "/tmp/scriptnewsfeed.sh"
#   }

#   provisioner "remote-exec" {
#       inline = [
#       "chmod +x /tmp/scriptnewsfeed.sh",
#       "source /tmp/scriptnewsfeed.sh",
#       "sudo systemctl enable Newsfeed",
#       "sudo systemctl start Newsfeed"
#     ]
#   }
# }

# resource "null_resource" "frontend" {
#   depends_on = ["azurerm_virtual_machine.test"]

#   triggers = {
#     vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id, 3)}"
#   }

#   connection {
#     type     = "ssh"
#     host     = "${element(azurerm_public_ip.ipforbackendvm.*.ip_address, 3)}"
#     user     = "${var.admin_username}"
#     password = "${var.admin_password}"
#   }

#   provisioner "file" {
#     source      = "scriptfrontend.sh"
#     destination = "/tmp/scriptfrontend.sh"
#   }

#   provisioner "remote-exec" {
#       inline = [
#       "chmod +x /tmp/scriptfrontend.sh",
#       "source /tmp/scriptfrontend.sh",
#       "sudo systemctl enable FrontEnd",
#       "sudo systemctl start FrontEnd"
#     ]
#   }
# }
output "public_ip_addresses" {
  value = "${join("-", azurerm_public_ip.ipforbackendvm.*.ip_address)}"
}