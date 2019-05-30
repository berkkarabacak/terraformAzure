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

# resource "azurerm_public_ip" "publicIPForLB" {
#  name                         = "publicIPForLB"
#  location                     = "${azurerm_resource_group.test.location}"
#  resource_group_name          = "${azurerm_resource_group.test.name}"
#  allocation_method            = "Static"
# }

resource "azurerm_public_ip" "ipforbackendvm_resource" {
 count                        = "${var.redundancy_count}"
 name                         = "ipforbackendvm_${count.index}"
 location                     = "${azurerm_resource_group.test.location}"
 resource_group_name          = "${azurerm_resource_group.test.name}"
 allocation_method            = "Static"
}

# resource "azurerm_lb" "test" {
#  name                = "loadBalancer"
#  location            = "${azurerm_resource_group.test.location}"
#  resource_group_name = "${azurerm_resource_group.test.name}"

#  frontend_ip_configuration {
#    name                 = "publicIPAddress"
#    public_ip_address_id = "${azurerm_public_ip.publicIPForLB.id}"
#  }
# }

# resource "azurerm_lb_backend_address_pool" "test" {
#  resource_group_name = "${azurerm_resource_group.test.name}"
#  loadbalancer_id     = "${azurerm_lb.test.id}"
#  name                = "BackEndAddressPool"
# }

resource "azurerm_network_interface" "test" {
 count               = "${var.redundancy_count}"
 name                = "${var.prefix}_ni${count.index}"
 location            = "${azurerm_resource_group.test.location}"
 resource_group_name = "${azurerm_resource_group.test.name}"

 ip_configuration {
   name                          = "testConfiguration${count.index}"
   subnet_id                     = "${azurerm_subnet.test.id}"
   private_ip_address_allocation = "dynamic"
   public_ip_address_id           = "${element(azurerm_public_ip.ipforbackendvm_resource.*.id, count.index)}"
  #  load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.test.id}"]
 }
}

# resource "azurerm_network_interface_backend_address_pool_association" "test" {
#   count                   = "${var.redundancy_count}"
#   network_interface_id    = "${element(azurerm_network_interface.test.*.id, count.index)}"
#   ip_configuration_name   = "testconfiguration${count.index}"
#   backend_address_pool_id = "${azurerm_lb_backend_address_pool.test.id}"
# }

resource "azurerm_managed_disk" "test" {
 count                = "${var.redundancy_count}"
 name                 = "${var.prefix}_datadisk_existing_${count.index}"
 location             = "${azurerm_resource_group.test.location}"
 resource_group_name  = "${azurerm_resource_group.test.name}"
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

# resource "azurerm_availability_set" "avset" {
#  name                         = "${var.prefix}_avset"
#  location                     = "${azurerm_resource_group.test.location}"
#  resource_group_name          = "${azurerm_resource_group.test.name}"
#  platform_fault_domain_count  = 2
#  platform_update_domain_count = 2
#  managed                      = true
# }

resource "azurerm_virtual_machine" "test" {
 count                 = "${var.redundancy_count}"
 name                  = "berkkaravm${count.index}"
 location              = "${azurerm_resource_group.test.location}"
#  availability_set_id   = "${azurerm_availability_set.avset.id}"
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
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks
 storage_data_disk {
   name              = "datadisk_new_${count.index}"
   managed_disk_type = "Standard_LRS"
   create_option     = "Empty"
   lun               = 0
   disk_size_gb      = "1023"
 }

 storage_data_disk {
   name            = "${element(azurerm_managed_disk.test.*.name, count.index)}"
   managed_disk_id = "${element(azurerm_managed_disk.test.*.id, count.index)}"
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = "${element(azurerm_managed_disk.test.*.disk_size_gb, count.index)}"
 }

 os_profile {
   computer_name  = "hostname"
   admin_username = "${var.admin_username}"
   admin_password = "${var.admin_password}"
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = {
   environment = "staging"
 }
}

data "azurerm_public_ip" "ipforbackendvm" {
  count               = "${var.redundancy_count}"
  name                = "${element(azurerm_public_ip.ipforbackendvm_resource.*.name, count.index)}"
  resource_group_name = "${element(azurerm_virtual_machine.test.*.resource_group_name, count.index)}"
}

resource "null_resource" "assets" {
  # Changes to any instance of the vms requires re-provisioning
  triggers = {
    vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id,0)}"
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
      type     = "ssh"
      host     = "${element(data.azurerm_public_ip.ipforbackendvm.*.ip_address,0)}"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      }

    provisioner "file" {
        source      = "assets_script.sh"
        destination = "home/berk/script.sh"
      }

      provisioner "remote-exec" {
        inline = [
          "chmod +x /home/berk/script.sh",
          "/home/berk/script.sh args",
        ]
      }
}

resource "null_resource" "quote" {
  # Changes to any instance of the vms requires re-provisioning
  triggers = {
    vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id,1)}"
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
      type     = "ssh"
      host     = "${element(data.azurerm_public_ip.ipforbackendvm.*.ip_address,1)}"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      }

    provisioner "file" {
      source      = "quotescript.sh"
      destination = "home/berk/script.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /home/berk/script.sh",
        "/home/berk/script.sh args",
      ]
    }
}


resource "null_resource" "Newsfeed" {
  # Changes to any instance of the vms requires re-provisioning
  triggers = {
    vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id,2)}"
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
      type     = "ssh"
      host     = "${element(data.azurerm_public_ip.ipforbackendvm.*.ip_address,2)}"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      }

  
    provisioner "file" {
      source      = "newsfeed.sh"
      destination = "home/berk/script.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /home/berk/script.sh",
        "/home/berk/script.sh args",
      ]
    }
}


resource "null_resource" "frontend" {
  # Changes to any instance of the vms requires re-provisioning
  triggers = {
    vm_instance_ids = "${element(azurerm_virtual_machine.test.*.id,3)}"
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
      type     = "ssh"
      host     = "${element(data.azurerm_public_ip.ipforbackendvm.*.ip_address,3)}"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      }
    
    provisioner "file" {
      source      = "frontendscript.sh"
      destination = "home/berk/script.sh"
    }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /home/berk/script.sh",
        "/home/berk/script.sh args",
      ]
    }
}
output "public_ip_addresses" {
  value = "${join("-", data.azurerm_public_ip.ipforbackendvm.*.ip_address)}"
}