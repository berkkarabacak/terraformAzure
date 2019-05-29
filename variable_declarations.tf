variable subscription_id {}
variable tenant_id {}
variable client_id {}
variable client_secret {}
variable vm_count {
       default = 3
}

provider "azurerm" {
   subscription_id = "${var.subscription_id}"
   tenant_id = "${var.tenant_id}"
   client_id = "${var.client_id}"
   client_secret = "${var.client_secret}"
}
