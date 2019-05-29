variable "subscription_id" {
}

variable "tenant_id" {
}

variable "client_id" {
}

variable "client_secret" {
}

variable "admin_username" {
  default = "berk"
}

variable "admin_password" {
  default = "Berk123123123"
}

provider "azurerm" {
  version = "=1.29.0"
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

