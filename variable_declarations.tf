
variable "admin_username" {
  default = "berk"
}

variable "redundancy_count" {
  default = 3
}

variable "prefix" {
  default = "berkcuma"
}

variable "admin_password" {
  default = "Berk123123"
}
variable "QuoteServicePort" {
  default = "8080"
}
variable "NewsfeedServicePort" {
  default = "8080"
}
variable "FrontEndServicePort" {
  default = "8080"
}

provider "azurerm" {
  version         = "=1.29.0"
  subscription_id = "4d048e66-d095-4bce-ba91-64ad63809962"
  tenant_id       = "b67d722d-aa8a-4777-a169-ebeb7a6a3b67"
  client_id       = "c8a0e08f-9abe-44c6-bb81-e393694df3f9"
  client_secret   = "df0e83f3-284a-4126-b719-01765bd0ebd5"
}

