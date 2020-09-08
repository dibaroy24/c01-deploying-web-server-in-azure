variable "location" {
  description = "The location where resources are created"
  default     = "East US"
}

variable "prefix" {
  description = "The value of the prefix will be used in naming of all resources in this exercise"
  default = "myudacityservc01"
}

variable "resource_group_name" {
  description = "The name of the resource group in which the resources are created"
  default     = "myudacitytfrmdrc01-rg"
}

variable "no_of_instances" {
  description = "Number of instances to be deployed"
  default = 2
}

variable "admin_password" {
    description = "Default password for admin"
    default = "Password1234!"
}